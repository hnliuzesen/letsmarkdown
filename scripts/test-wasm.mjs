import assert from "assert";
import { readFile } from "fs/promises";
import init, { OpSeq } from "../letsmarkdown-wasm/pkg/letsmarkdown_wasm.js";

// Exercise the generated JavaScript bindings: native Rust tests cannot catch
// incorrect UTF-8 buffer allocation when passing strings into WebAssembly.
await init(
  await readFile(
    new URL(
      "../letsmarkdown-wasm/pkg/letsmarkdown_wasm_bg.wasm",
      import.meta.url
    )
  )
);

const pastedCommands = `

# 查看 SSD 的准确型号和当前固件版本
lsblk -d -o NAME,MODEL,SIZE,REV

# 检查固件管理工具是否存在
command -v fwupdmgr

# 如果存在，查看识别到的设备及更新记录
fwupdmgr get-devices
fwupdmgr get-updates
fwupdmgr get-history
`;

for (const text of [
  "plain text",
  "第一行\n第二行",
  pastedCommands,
  `😀 ${pastedCommands}`,
  pastedCommands.repeat(100),
]) {
  const original = "11122";
  const operations = [];
  const edit = OpSeq.new();
  operations.push(edit);
  edit.retain(original.length);
  edit.insert(text);
  assert.strictEqual(edit.apply(original), original + text);
  assert.strictEqual(edit.target_len(), [...(original + text)].length);

  const received = OpSeq.from_str(edit.to_string());
  assert.ok(received);
  operations.push(received);
  assert.strictEqual(received.apply(original), original + text);

  const prior = OpSeq.new();
  operations.push(prior);
  prior.insert(original);
  const composed = prior.compose(edit);
  assert.ok(composed);
  operations.push(composed);
  assert.strictEqual(composed.apply(""), original + text);
  for (const operation of operations) operation.free();
}

console.log("WASM paste regression checks passed.");
