## 0.1.2:
- Fixed server instance map script to not throw error when attemping to set an attribute on an internal instance.
- Minor polishes.
## 0.1.1:
- Added Union, BoolPacked type
- Color3, CFrame(and its variants), vector(and its variants), Vector2(and its variants) are now primitives(moved into bufferWriter & bufferReader)
- Added UInt40, Int40, UInt48, Int48, CFrameF16, QCFrameF16 types
- Fixed GetItemType type function to properly work with Luau LSP
- Code quality improvements
- Improved Documentation
- Micro Optimizations
- Added manual serialization support (`writeStart`, `writeFinish`, `readStart`, `readFinish`, `getWriteCursor`, `getReadCursor`)
- The benchmarks are now more concise

## 0.1.0:
- Release