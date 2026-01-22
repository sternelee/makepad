use crate::{
    cx::Cx,
    event::Event,
    audio::*,
    midi::*,
    video::*,
    media_api::CxMediaApi,
    makepad_live_id::*,
};

#[derive(Clone)]
pub struct OsMidiOutput {
}

impl OsMidiOutput {
    pub fn send(&self, _port_id: Option<MidiPortId>, _data: MidiData) {
    }
}

pub struct OsMidiInput {
}

impl OsMidiInput {
    pub fn receive(&mut self) -> Option<(MidiPortId, MidiData)> {
        None
    }
}

// Audio stream types for HarmonyOS
pub struct OhAudioOutputStream {
    pub is_active: bool,
    pub sample_rate: u32,
    pub channels: u32,
    pub buffer_size: usize,
    pub audio_fn: Option<AudioOutputFn>,
}

pub struct OhAudioInputStream {
    pub is_active: bool,
    pub sample_rate: u32,
    pub channels: u32,
    pub buffer_size: usize,
    pub audio_fn: Option<AudioInputFn>,
}

impl OhAudioOutputStream {
    pub fn new(sample_rate: u32, channels: u32, buffer_size: usize) -> Self {
        Self {
            is_active: false,
            sample_rate,
            channels,
            buffer_size,
            audio_fn: None,
        }
    }

    pub fn start(&mut self) {
        self.is_active = true;
    }

    pub fn stop(&mut self) {
        self.is_active = false;
    }

    pub fn process(&mut self, device_id: AudioDeviceId, frame_count: usize, channel_count: usize) {
        if !self.is_active {
            return;
        }
        if let Some(ref mut audio_fn) = self.audio_fn {
            let mut buffer = AudioBuffer::new_with_size(frame_count, channel_count);
            audio_fn(
                AudioInfo {
                    device_id,
                    time: None,
                    sample_rate: self.sample_rate as f64,
                },
                &mut buffer,
            );
        }
    }
}

impl OhAudioInputStream {
    pub fn new(sample_rate: u32, channels: u32, buffer_size: usize) -> Self {
        Self {
            is_active: false,
            sample_rate,
            channels,
            buffer_size,
            audio_fn: None,
        }
    }

    pub fn start(&mut self) {
        self.is_active = true;
    }

    pub fn stop(&mut self) {
        self.is_active = false;
    }

    pub fn process(&mut self, device_id: AudioDeviceId, data: &[f32], _frame_count: usize, channel_count: usize) {
        if !self.is_active {
            return;
        }
        if let Some(ref mut audio_fn) = self.audio_fn {
            let buffer = AudioBuffer::from_data(data.to_vec(), channel_count);
            audio_fn(
                AudioInfo {
                    device_id,
                    time: None,
                    sample_rate: self.sample_rate as f64,
                },
                &buffer,
            );
        }
    }
}

// Video input types for HarmonyOS
pub struct OhVideoInputStream {
    pub is_active: bool,
    pub width: usize,
    pub height: usize,
    pub frame_rate: f64,
    pub video_fn: Option<VideoInputFn>,
    pub surface_id: String,
}

impl OhVideoInputStream {
    pub fn new(width: usize, height: usize, frame_rate: f64) -> Self {
        Self {
            is_active: false,
            width,
            height,
            frame_rate,
            video_fn: None,
            surface_id: String::new(),
        }
    }

    pub fn start(&mut self) {
        self.is_active = true;
    }

    pub fn stop(&mut self) {
        self.is_active = false;
    }

    pub fn process_frame(&mut self, data: &[u8], width: usize, height: usize) {
        if !self.is_active {
            return;
        }
        if let Some(ref mut video_fn) = self.video_fn {
            let buffer_ref = VideoBufferRef {
                format: VideoFormat {
                    format_id: VideoFormatId(LiveId::from_str("default")),
                    width,
                    height,
                    frame_rate: Some(self.frame_rate),
                    pixel_format: VideoPixelFormat::NV12,
                },
                data: VideoBufferRefData::U8(data),
            };
            video_fn(buffer_ref);
        }
    }
}

#[derive(Default)]
pub struct CxOpenHarmonyMedia {
    pub audio_outputs: Vec<Option<OhAudioOutputStream>>,
    pub audio_inputs: Vec<Option<OhAudioInputStream>>,
    pub audio_output_devices: Vec<AudioDeviceDesc>,
    pub audio_input_devices: Vec<AudioDeviceDesc>,
    pub video_inputs: Vec<Option<OhVideoInputStream>>,
    pub video_input_devices: Vec<VideoInputDesc>,
    pub clipboard_content: Option<String>,
}

impl Cx {
    pub (crate) fn handle_media_signals(&mut self) {
    }

    pub fn reinitialise_media(&mut self) {
        // Discover and register audio devices
        self.os.media.audio_output_devices = vec![
            AudioDeviceDesc {
                device_id: AudioDeviceId(LiveId::from_str("default_output")),
                device_type: AudioDeviceType::Output,
                is_default: true,
                has_failed: false,
                channel_count: 2,
                name: "Default Output".to_string(),
            }
        ];

        self.os.media.audio_input_devices = vec![
            AudioDeviceDesc {
                device_id: AudioDeviceId(LiveId::from_str("default_input")),
                device_type: AudioDeviceType::Input,
                is_default: true,
                has_failed: false,
                channel_count: 1,
                name: "Default Input".to_string(),
            }
        ];

        // Send device discovery event
        let event = Event::AudioDevices(AudioDevicesEvent {
            descs: self.os.media.audio_output_devices.clone()
                .into_iter()
                .chain(self.os.media.audio_input_devices.clone())
                .collect(),
        });
        self.call_event_handler(&event);

        // Discover and register video devices
        self.os.media.video_input_devices = vec![
            VideoInputDesc {
                input_id: VideoInputId(LiveId::from_str("default_camera")),
                name: "Default Camera".to_string(),
                formats: vec![
                    VideoFormat {
                        format_id: VideoFormatId(LiveId::from_str("camera_720p")),
                        width: 1280,
                        height: 720,
                        frame_rate: Some(30.0),
                        pixel_format: VideoPixelFormat::NV12,
                    },
                    VideoFormat {
                        format_id: VideoFormatId(LiveId::from_str("camera_1080p")),
                        width: 1920,
                        height: 1080,
                        frame_rate: Some(30.0),
                        pixel_format: VideoPixelFormat::NV12,
                    },
                ],
            }
        ];

        // Send video device discovery event
        let video_event = Event::VideoInputs(VideoInputsEvent {
            descs: self.os.media.video_input_devices.clone(),
        });
        self.call_event_handler(&video_event);
    }

    pub fn ohos_start_audio_output(&mut self, device_id: AudioDeviceId, sample_rate: u32, channels: u32) {
        let args = [
            self.create_napi_number(device_id.0.get_value() as f64),
            self.create_napi_number(sample_rate as f64),
            self.create_napi_number(channels as f64),
        ];
        let _ = self.os.arkts_obj.as_mut().unwrap().call_js_function(
            "startAudioOutput",
            3,
            args.as_ptr() as *const _,
        );
    }

    pub fn ohos_stop_audio_output(&mut self, device_id: AudioDeviceId) {
        let args = [self.create_napi_number(device_id.0.get_value() as f64)];
        let _ = self.os.arkts_obj.as_mut().unwrap().call_js_function(
            "stopAudioOutput",
            1,
            args.as_ptr() as *const _,
        );
    }

    pub fn ohos_start_audio_input(&mut self, device_id: AudioDeviceId, sample_rate: u32, channels: u32) {
        let args = [
            self.create_napi_number(device_id.0.get_value() as f64),
            self.create_napi_number(sample_rate as f64),
            self.create_napi_number(channels as f64),
        ];
        let _ = self.os.arkts_obj.as_mut().unwrap().call_js_function(
            "startAudioInput",
            3,
            args.as_ptr() as *const _,
        );
    }

    pub fn ohos_stop_audio_input(&mut self, device_id: AudioDeviceId) {
        let args = [self.create_napi_number(device_id.0.get_value() as f64)];
        let _ = self.os.arkts_obj.as_mut().unwrap().call_js_function(
            "stopAudioInput",
            1,
            args.as_ptr() as *const _,
        );
    }

    pub fn ohos_write_audio_data(&mut self, data: &[f32]) {
        // Convert float data to Int16 for OHOS
        let i16_data: Vec<i16> = data.iter().map(|&v| {
            (v * 32767.0).max(-32768.0).min(32767.0) as i16
        }).collect();

        // Create ArrayBuffer and call JS function
        let args = [self.create_napi_buffer(&i16_data)];
        let _ = self.os.arkts_obj.as_mut().unwrap().call_js_function(
            "writeAudioData",
            1,
            args.as_ptr() as *const _,
        );
    }

    pub fn ohos_start_video_input(&mut self, width: usize, height: usize, frame_rate: f64) {
        let args = [
            self.create_napi_number(width as f64),
            self.create_napi_number(height as f64),
            self.create_napi_number(frame_rate),
        ];
        let _ = self.os.arkts_obj.as_mut().unwrap().call_js_function(
            "startVideoInput",
            3,
            args.as_ptr() as *const _,
        );
    }

    pub fn ohos_stop_video_input(&mut self) {
        let _ = self.os.arkts_obj.as_mut().unwrap().call_js_function(
            "stopVideoInput",
            0,
            std::ptr::null(),
        );
    }
}

impl CxOpenHarmonyMedia {
}

impl CxMediaApi for Cx {

    fn midi_input(&mut self) -> MidiInput {
        MidiInput(Some(OsMidiInput {}))
    }

    fn midi_output(&mut self) -> MidiOutput {
        MidiOutput(Some(OsMidiOutput {}))
    }

    fn midi_reset(&mut self) {}

    fn use_midi_inputs(&mut self, _ports: &[MidiPortId]) {
    }

    fn use_midi_outputs(&mut self, _ports: &[MidiPortId]) {
    }

    fn use_audio_inputs(&mut self, devices: &[AudioDeviceId]) {
        // Expand audio_inputs array if needed
        for device_id in devices {
            let index = device_id.0.get_value() as usize;
            while self.os.media.audio_inputs.len() <= index {
                self.os.media.audio_inputs.push(None);
            }
            self.os.media.audio_inputs[index] = Some(OhAudioInputStream::new(44100, 1, 1024));
        }
    }

    fn use_audio_outputs(&mut self, devices: &[AudioDeviceId]) {
        // Expand audio_outputs array if needed
        for device_id in devices {
            let index = device_id.0.get_value() as usize;
            while self.os.media.audio_outputs.len() <= index {
                self.os.media.audio_outputs.push(None);
            }
            self.os.media.audio_outputs[index] = Some(OhAudioOutputStream::new(44100, 2, 1024));
        }
    }

    fn audio_output_box(&mut self, index: usize, f: AudioOutputFn) {
        if let Some(ref mut output) = self.os.media.audio_outputs[index] {
            let sample_rate = output.sample_rate;
            let channels = output.channels;
            output.audio_fn = Some(f);
            output.start();
            let device_id = self.os.media.audio_output_devices.get(0).map(|d| d.device_id).unwrap();
            self.ohos_start_audio_output(device_id, sample_rate, channels);
        }
    }

    fn audio_input_box(&mut self, index: usize, f: AudioInputFn) {
        if let Some(ref mut input) = self.os.media.audio_inputs[index] {
            let sample_rate = input.sample_rate;
            let channels = input.channels;
            input.audio_fn = Some(f);
            input.start();
            let device_id = self.os.media.audio_input_devices.get(0).map(|d| d.device_id).unwrap();
            self.ohos_start_audio_input(device_id, sample_rate, channels);
        }
    }

    fn video_input_box(&mut self, index: usize, f: VideoInputFn) {
        if let Some(ref mut input) = self.os.media.video_inputs[index] {
            let width = input.width;
            let height = input.height;
            let frame_rate = input.frame_rate;
            input.video_fn = Some(f);
            input.start();
            self.ohos_start_video_input(width, height, frame_rate);
        }
    }

    fn use_video_input(&mut self, inputs: &[(VideoInputId, VideoFormatId)]) {
        // Find and initialize the requested video inputs
        for (input_id, format_id) in inputs {
            if let Some(device) = self.os.media.video_input_devices.iter()
                .find(|d| d.input_id == *input_id) {
                if let Some(format) = device.formats.iter()
                    .find(|f| f.format_id == *format_id) {
                    let index = input_id.0.get_value() as usize;
                    while self.os.media.video_inputs.len() <= index {
                        self.os.media.video_inputs.push(None);
                    }
                    self.os.media.video_inputs[index] = Some(OhVideoInputStream::new(
                        format.width,
                        format.height,
                        format.frame_rate.unwrap_or(30.0),
                    ));
                }
            }
        }
    }
}
