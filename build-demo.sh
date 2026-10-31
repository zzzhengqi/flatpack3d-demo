#!/bin/sh
# 生成在线演示网站：工具仓库 main 已提交的网页文件 + 演示用到的说明书页面图（不含商品图、PDF）
# 用法：sh build-demo.sh <工具仓库目录> <演示仓库目录>
set -e
SRC="$1"; OUT="$2"
[ -f "$SRC/index.html" ] && [ -d "$OUT/.git" ] || { echo "用法：sh build-demo.sh <工具仓库> <演示仓库（已 git init）>"; exit 1; }
# 清空旧文件（保留 .git）
find "$OUT" -mindepth 1 -maxdepth 1 ! -name .git ! -name build-demo.sh -exec rm -rf {} +
# 只取网页需要的、已提交的文件
git -C "$SRC" archive HEAD index.html en data vendor brand .nojekyll LICENSE | tar -x -C "$OUT"
# 说明书页面图：只放各件步骤用到的页和安全警告页
node -e '
const fs = require("fs"), path = require("path");
const [src, out] = process.argv.slice(1);
const prod = JSON.parse(fs.readFileSync(path.join(src, "data/products.json"), "utf8"));
const copied = [];
for (const p of prod.products || prod) {
  const id = p.id || p;
  const man = JSON.parse(fs.readFileSync(path.join(src, "data", id, "manifest.json"), "utf8"));
  const zh = JSON.parse(fs.readFileSync(path.join(src, "data", id, "product.zh.json"), "utf8"));
  for (const f of fs.readdirSync(path.join(src, "data", id)).filter((f) => f.endsWith(".json"))) {
    const d = JSON.parse(fs.readFileSync(path.join(src, "data", id, f), "utf8"));
    if (!d.manualPages) continue;
    const pages = new Set();
    const walk = (o) => { if (Array.isArray(o)) o.forEach(walk); else if (o && typeof o === "object") { if (Array.isArray(o.pages)) o.pages.forEach((n) => pages.add(n)); Object.values(o).forEach(walk); } };
    walk(d);
    if (zh.safety && zh.safety.page && f === "body.json") pages.add(zh.safety.page);
    for (const n of pages) {
      const rel = path.join(d.manualPages.dir, d.manualPages.pattern.replace("{NN}", String(n).padStart(2, "0")));
      if (!fs.existsSync(path.join(src, rel))) { console.error("缺页面图：" + rel); process.exit(1); }
      fs.mkdirSync(path.dirname(path.join(out, rel)), { recursive: true });
      fs.copyFileSync(path.join(src, rel), path.join(out, rel));
      copied.push(rel);
    }
  }
}
console.log("页面图 " + copied.length + " 张");
' "$SRC" "$OUT"
cat > "$OUT/README.md" <<'EOF'
# FlatPack3D 在线演示

由 [FlatPack3D](https://github.com/zzzhengqi/FlatPack3D) 生成的 KALLAX 3D 装配演示网站。

本演示与宜家无关，未经宜家认可；KALLAX 和 IKEA 是 Inter IKEA Systems B.V. 的商标。说明书页面图取自宜家官方装配说明书，版权归 Inter IKEA Systems B.V.，仅用于对照演示；如有异议请[联系我们](https://github.com/zzzhengqi/FlatPack3D/issues)，我们会立即删除。
EOF
echo "完成：$OUT"
