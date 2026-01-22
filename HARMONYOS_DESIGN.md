# HarmonyOS Platform Enhancement Design Plan

## Implementation Status (Updated 2025-01-22 - FINAL)

| Feature | Status | Notes |
|---------|--------|-------|
| **Audio Output/Input** | ✅ Implemented | `oh_media.rs` + ArkTS glue code |
| **Clipboard** | ✅ Implemented | `open_harmony.rs` + ArkTS pasteboard API |
| **Permissions** | ✅ Implemented | `open_harmony.rs` + ArkTS abilityAccessCtrl |
| **Video/Camera** | ✅ Implemented | `oh_media.rs` + ArkTS camera API |
| **Notifications** | ✅ Implemented | `open_harmony.rs` + ArkTS notificationManager |
| **Network Status** | ✅ Implemented | `open_harmony.rs` + ArkTS network API |
| **File Picker** | ✅ Implemented | `open_harmony.rs` + ArkTS picker API |
| **Vibration** | ✅ Implemented | `open_harmony.rs` + ArkTS vibrator API |

**Overall Progress: ~98% complete** (up from 85%)

## Recent Changes - Final Implementation

### 1. Audio Support (✅ Complete)
- **File**: `platform/src/os/linux/open_harmony/oh_media.rs`
  - Added `OhAudioOutputStream` and `OhAudioInputStream` structs
  - Implemented `audio_output_box()` and `audio_input_box()` methods
  - NAPI bridge functions for JavaScript audio APIs
- **ArkTS**: `tools/open_harmony/deveco/entry/src/main/ets/makepad/makepad.ets`
  - `startAudioOutput()` / `stopAudioOutput()` using @ohos.multimedia.audio
  - `startAudioInput()` / `stopAudioInput()` for microphone access
  - `writeAudioData()` / `readAudioData()` for buffer management

### 2. Clipboard Support (✅ Complete)
- **File**: `platform/src/os/linux/open_harmony/open_harmony.rs`
  - Added `CxOsOp::CopyToClipboard` handler in `handle_platform_ops()`
  - Integrated with `CxOsOp::ShowClipboardActions` and `HideClipboardActions`
- **ArkTS**: `makepad.ets`
  - `copyToClipboard()` using @ohos.pasteboard
  - `pasteFromClipboard()` for reading clipboard content

### 3. Permissions Handling (✅ Complete)
- **File**: `platform/src/os/linux/open_harmony/open_harmony.rs`
  - Added `ohos_check_permission()` method
  - Added `ohos_request_permission()` method
  - Handles `CxOsOp::CheckPermission` and `CxOsOp::RequestPermission`
- **ArkTS**: `makepad.ets`
  - `requestMicrophonePermission()` using @ohos.abilityAccessCtrl
  - `checkPermission()` for checking permission status

### 4. Video/Camera Support (✅ Complete)
- **File**: `platform/src/os/linux/open_harmony/oh_media.rs`
  - Added `OhVideoInputStream` struct
  - Implemented `video_input_box()` and `use_video_input()` methods
  - Video device discovery with NV12 format support
- **ArkTS**: `makepad.ets`
  - `startVideoInput()` / `stopVideoInput()` using @ohos.multimedia.camera
  - `setVideoSurfaceId()` for surface binding
  - Support for 720p and 1080p resolutions at 30fps

### 5. Notifications (✅ Complete)
- **File**: `platform/src/os/linux/open_harmony/open_harmony.rs`
  - Added `ohos_show_notification()` method
- **ArkTS**: `makepad.ets`
  - `showNotification()` using @ohos.notificationManager
  - `cancelNotification()` for notification management

### 6. Network Status Monitoring (✅ Complete)
- **File**: `platform/src/os/linux/open_harmony/open_harmony.rs`
  - Added `ohos_start_network_monitoring()` method
  - Added `ohos_stop_network_monitoring()` method
- **ArkTS**: `makepad.ets`
  - `startNetworkMonitoring()` / `stopNetworkMonitoring()` using @ohos.net.connection
  - `getNetworkState()` for current network type
  - Network state change callbacks

### 7. File Picker Dialogs (✅ Complete)
- **File**: `platform/src/os/linux/open_harmony/open_harmony.rs`
  - Added `ohos_show_file_picker()` method
  - Added `ohos_show_file_saver()` method
- **ArkTS**: `makepad.ets`
  - `showFilePicker()` using @ohos.file.picker.DocumentViewPicker
  - `showFileSaver()` for saving files
  - Support for multiple file extensions

### 8. Vibration/Haptic Feedback (✅ Complete)
- **File**: `platform/src/os/linux/open_harmony/open_harmony.rs`
  - Integration via ArkTS bridge
- **ArkTS**: `makepad.ets`
  - `vibrate(duration)` using @ohos.vibrator
  - `stopVibration()` for cancellation
  - `vibratePattern()` for custom vibration patterns

---

## Original Design Document

## Current Status

Makepad's HarmonyOS support is approximately **85% complete** with solid UI/rendering foundation but gaps in media and platform features.

### Implemented Features ✅
- Full OpenGL ES rendering via EGL
- Touch input with multi-touch support
- Text input with IME integration
- File system access (ResourceManager)
- VSync-driven rendering loop
- Cross-architecture support (ARM64, x86_64)
- DevEco Studio integration
- HAP packaging and deployment
- HDC remote device support

### Missing Features ❌
- Audio input/output
- Video capture
- MIDI support
- Clipboard
- Notifications
- Camera access
- Permissions handling
- Network status monitoring
- File picker dialogs
- Vibration/haptic feedback
- Background execution

## Design Proposals

### 1. Audio Support (Priority: HIGH)

**Location**: `platform/src/os/linux/open_harmony/oh_audio.rs` (new file)

**OHOS Audio APIs**:
- `OH_AudioStreamBuilder`: For creating audio streams
- `OH_AudioStream`: For playback/recording operations
- NAPI bridge to ArkTS audio components

**Implementation Structure**:

```rust
// New file: platform/src/os/linux/open_harmony/oh_audio.rs

use napi_ohos::*;
use crate::audio::*;

pub struct OhAudioOutputStream {
    stream: *mut OH_AudioStream,
    buffer_size: usize,
}

pub struct OhAudioInputStream {
    stream: *mut OH_AudioStream,
    callback_data: AudioCallbackData,
}

impl OhAudioOutputStream {
    pub fn new(
        sample_rate: u32,
        channels: u32,
        buffer_size: usize,
    ) -> Result<Self, String> {
        // Use OH_AudioStreamBuilder_Create()
        // Configure for playback
        // Set buffer size
    }

    pub fn write(&mut self, data: &[f32]) -> Result<(), String> {
        // OH_AudioStream_Write()
    }
}

// Audio callback via NAPI to JavaScript
unsafe extern "C" fn audio_stream_callback(
    stream: *mut OH_AudioStream,
    offset: usize,
    user_data: *mut c_void,
) -> i32 {
    // Bridge to Rust audio processing
}
```

**Integration with existing CxMediaApi**:

```rust
// In oh_media.rs
impl CxMediaApi for Cx {
    fn audio_output_box(&mut self, index: usize, f: AudioOutputFn) {
        self.os.media.audio_output.as_mut()
            .unwrap()
            .process(index, f);
    }

    fn audio_input_box(&mut self, index: usize, f: AudioInputFn) {
        self.os.media.audio_input.as_mut()
            .unwrap()
            .process(index, f);
    }

    fn use_audio_outputs(&mut self, devices: &[AudioDeviceId]) {
        // Initialize OH_AudioStream for playback
    }

    fn use_audio_inputs(&mut self, devices: &[AudioDeviceId]) {
        // Initialize OH_AudioStream for capture
    }
}
```

**ArkTS Integration** (add to `tools/open_harmony/deveco/entry/src/main/ets/`):

```typescript
// New file: makepad/OhAudioGlue.ets
import audio from '@ohos.multimedia.audio';

export class OhAudioGlue {
    private static audioRenderer: audio.AudioRenderer | null = null;
    private static audioCapturer: audio.AudioCapturer | null = null;

    static async initAudioRenderer(sampleRate: number, channels: number) {
        const audioStreamInfo: audio.AudioStreamInfo = {
            samplingRate: sampleRate,
            channels: channels,
            sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S32LE,
            encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        };

        const audioRendererInfo: audio.AudioRendererInfo = {
            usage: audio.StreamUsage.STREAM_USAGE_MEDIA,
            rendererFlags: 0
        };

        const audioRendererOptions: audio.AudioRendererOptions = {
            streamInfo: audioStreamInfo,
            rendererInfo: audioRendererInfo
        };

        this.audioRenderer = await audio.createAudioRenderer(audioRendererOptions);
    }

    static async writeAudioData(buffer: ArrayBuffer) {
        if (this.audioRenderer) {
            await this.audioRenderer.write(buffer);
        }
    }
}
```

### 2. Video/Camera Support (Priority: MEDIUM)

**Location**: `platform/src/os/linux/open_harmony/oh_video.rs` (new file)

**OHOS Camera APIs**:
- `@ohos.multimedia.camera`: Camera module
- `@ohos.multimedia.media`: Video recording

**Implementation Structure**:

```rust
// New file: platform/src/os/linux/open_harmony/oh_video.rs

pub struct OhCameraInput {
    camera_id: String,
    surface_id: String,
}

impl OhCameraInput {
    pub fn new(camera_id: &str) -> Result<Self, String> {
        // Initialize via NAPI
    }

    pub fn start(&mut self) -> Result<(), String> {
        // Call ArkTS camera.start()
    }

    pub fn get_frame(&mut self) -> Option<VideoFrame> {
        // Receive frame from ArkTS
    }
}
```

**ArkTS Integration**:

```typescript
// New file: makepad/OhCameraGlue.ets
import camera from '@ohos.multimedia.camera';
import media from '@ohos.multimedia.media';

export class OhCameraGlue {
    private static cameraManager: camera.CameraManager | null = null;
    private static cameraInput: camera.CameraInput | null = null;
    private static captureSession: camera.CaptureSession | null = null;

    static async initCamera() {
        this.cameraManager = camera.getCameraManager(globalThis.context);
        const cameras = this.cameraManager.getSupportedCameras();
        // Setup camera input, output, session
    }

    static async startPreview(surfaceId: string) {
        // Start preview on XComponent surface
    }
}
```

### 3. Clipboard Support (Priority: MEDIUM)

**Location**: Extend `platform/src/os/linux/open_harmony/open_harmony.rs`

**OHOS Clipboard APIs**: `@ohos.pasteboard`

**Implementation**:

```rust
// Add to CxOsOp handling in open_harmony.rs
CxOsOp::CopyToClipboard(text) => {
    self.os.arkts_obj.as_mut().unwrap()
        .call_js_function("copyToClipboard", 1, &text);
}
CxOsOp::PasteFromClipboard => {
    // Return result via callback
}
```

**ArkTS Integration**:

```typescript
// Add to makepad/ArkGlue.ets
import pasteboard from '@ohos.pasteboard';

copyToClipboard(text: string): void {
    const systemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text));
}

async pasteFromClipboard(): Promise<string> {
    const systemPasteboard = pasteboard.getSystemPasteboard();
    const data = await systemPasteboard.getData();
    return data.getPrimaryText();
}
```

### 4. Notifications (Priority: LOW)

**Location**: `platform/src/os/linux/open_harmony/oh_notification.rs` (new file)

**OHOS Notification APIs**: `@ohos.notificationManager`

**Implementation Structure**:

```rust
pub struct OhNotification {
    id: i32,
    title: String,
    content: String,
}

impl Cx {
    pub fn show_notification(&mut self, title: &str, content: &str) {
        self.os.arkts_obj.as_mut().unwrap()
            .call_js_function("showNotification", 2, &title, &content);
    }
}
```

### 5. Permissions Handling (Priority: HIGH)

**Location**: Extend `platform/src/os/linux/open_harmony/open_harmony.rs`

**OHOS Permission APIs**: `@ohos.abilityAccessCtrl`

**Implementation**:

```rust
pub enum OhPermission {
    Camera,
    Microphone,
    ReadFiles,
    WriteFiles,
    Internet,
}

impl Cx {
    pub async fn request_permission(&mut self, permission: OhPermission) -> bool {
        // Call ArkTS to request permission
        // Return result via callback
    }

    pub fn check_permission(&mut self, permission: OhPermission) -> bool {
        // Check permission status
    }
}
```

**ArkTS Integration**:

```typescript
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import { BusinessError } from '@ohos.base';

async function requestPermission(permission: string): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
        await atManager.requestPermissionsFromUser(globalThis.context, [permission]);
        return true;
    } catch (err) {
        return false;
    }
}
```

### 6. Network Status (Priority: MEDIUM)

**Location**: `platform/src/os/linux/open_harmony/oh_network.rs` (new file)

**OHOS Network APIs**: `@ohos.net.connection`

**Implementation**:

```rust
pub enum NetworkType {
    None,
    WiFi,
    Cellular,
    Ethernet,
}

pub struct OhNetworkMonitor {
    callback: Box<dyn Fn(NetworkType)>,
}

impl OhNetworkMonitor {
    pub fn start<F: Fn(NetworkType) + 'static>(&mut self, callback: F) {
        // Register network state listener via NAPI
    }
}
```

### 7. File Picker Dialogs (Priority: MEDIUM)

**Location**: Extend `CxOsApi` for OHOS

**OHOS File Picker APIs**: `@ohos.file.picker`

**Implementation**:

```rust
impl CxOsApi for Cx {
    fn show_file_picker(&mut self, filters: &[FileFilter]) -> Option<String> {
        // Call ArkTS PhotoViewPicker or DocumentViewPicker
        // Return selected file path
    }

    fn show_file_saver(&mut self, default_name: &str) -> Option<String> {
        // Call ArkTS save dialog
    }
}
```

### 8. Vibration (Priority: LOW)

**Location**: `platform/src/os/linux/open_harmony/oh_haptic.rs` (new file)

**OHOS Vibration APIs**: `@ohos.vibrator`

**Implementation**:

```rust
impl Cx {
    pub fn vibrate(&mut self, duration_ms: u32) {
        self.os.arkts_obj.as_mut().unwrap()
            .call_js_function("vibrate", 1, &duration_ms.to_string());
    }

    pub fn cancel_vibration(&mut self) {
        self.os.arkts_obj.as_mut().unwrap()
            .call_js_function("cancelVibration", 0, std::ptr::null_mut());
    }
}
```

## Build System Enhancements

### 1. Improved Dependency Management

Current `tools/cargo_makepad/src/open_harmony/compile.rs` could be enhanced:

- **Auto-detect DevEco SDK versions** (currently tries DB1-DB5)
- **Cache native library builds** for faster iteration
- **Parallel HAP builds** for multiple architectures

### 2. Code Signing Automation

Add automatic certificate/provisioning profile handling:

```rust
// Add to compile.rs
pub struct OhosSigningConfig {
    cert_file: PathBuf,
    profile_file: PathBuf,
    password: String,
}

pub fn sign_hap(
    hap_path: &Path,
    config: &OhosSigningConfig
) -> Result<(), String> {
    // Use OHOS signing tools
}
```

### 3. Debug Build Support

Currently only release builds are fully supported. Add debug symbol handling:

```rust
pub fn build_hap(
    deveco_home: &Option<String>,
    args: &[String],
    host_os: &HostOs,
    mode: BuildMode, // Debug or Release
) -> Result<(), String> {
    let build_mode = match mode {
        BuildMode::Debug => "debug",
        BuildMode::Release => "release",
    };
    // Pass to hvigor
}
```

## Testing Strategy

### Unit Tests

Create `platform/src/os/linux/open_harmony/tests/`:
- Audio stream lifecycle tests
- NAPI callback tests
- Resource file loading tests

### Integration Tests

- Build and run examples on actual device
- Test multi-touch input handling
- Verify EGL surface recreation on rotation

### Manual Testing Checklist

- [ ] Audio playback with various sample rates
- [ ] Audio recording with microphone
- [ ] Camera preview and capture
- [ ] Clipboard copy/paste
- [ ] Permission requests
- [ ] Network state changes
- [ ] File picker dialogs
- [ ] Vibration patterns

## Migration Notes

For existing Makepad apps adding HarmonyOS support:

1. **Add OHOS dependencies** to `Cargo.toml`:
```toml
[target.'cfg(target_env = "ohos")'.dependencies]
hilog-sys = "0.1.1"
napi-derive-ohos = "0.0.9"
napi-ohos = "0.1.3"
ohos-sys = { version = "0.2.1", features = ["xcomponent"] }
```

2. **Request permissions** in `module.json5`:
```json
{
  "requestPermissions": [
    {"name": "ohos.permission.INTERNET"},
    {"name": "ohos.permission.CAMERA"},
    {"name": "ohos.permission.MICROPHONE"},
    {"name": "ohos.permission.READ_MEDIA"},
    {"name": "ohos.permission.WRITE_MEDIA"}
  ]
}
```

3. **Conditionally compile platform-specific code**:
```rust
#[cfg(target_env = "ohos")]
{
    // OHOS-specific code
}
```

## Timeline Estimates

| Feature | Complexity | Estimate |
|---------|------------|----------|
| Audio Output | Medium | 2-3 days |
| Audio Input | Medium | 2-3 days |
| Video/Camera | High | 5-7 days |
| Clipboard | Low | 1 day |
| Notifications | Low | 1-2 days |
| Permissions | Medium | 2-3 days |
| Network Status | Low | 1 day |
| File Picker | Medium | 2-3 days |
| Vibration | Low | 0.5 day |
| Build Improvements | Medium | 3-5 days |

**Total**: ~20-30 days for complete feature parity with other platforms

## References

- [HarmonyOS Audio Development](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/audio-development-guide-V5)
- [HarmonyOS Camera Development](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/camera-development-guide-V5)
- [HarmonyOS NAPI](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/napi-guidelines-V5)
- [DevEco Studio Documentation](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-V5)
