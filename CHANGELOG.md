## 0.1.6:
- Merged upstream changes from BlazeSentry V0.1.7

## 0.1.5:
- Merged upstream changes from BlazeSentry V0.1.6

## 0.1.4:
- Fixed instanceMap not being populated with pesde package
- Minor code polishes

## 0.1.3:
- Fixed client instance map script to not throw error when attempting to get an attribute of an internal instance.
- Added `setConstant` for managing configurations.
- Added `updateBigBuffer` for updating the internal scratch buffer when `maxBufferSize` constant changes.
- Made the codebase compatible with the constants editing

## 0.1.2:
- Fixed server instance map script to not throw error when attempting to set an attribute on an internal instance.
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
