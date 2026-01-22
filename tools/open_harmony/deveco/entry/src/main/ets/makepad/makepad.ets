import display from '@ohos.display';
import deviceInfo from '@ohos.deviceInfo';
import inputMethod from '@ohos.inputMethod';
import audio from '@ohos.multimedia.audio';
import pasteboard from '@ohos.pasteboard';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import camera from '@ohos.multimedia.camera';
import notificationManager from '@ohos.notificationManager';
import network from '@ohos.net.connection';
import picker from '@ohos.file.picker';
import vibrator from '@ohos.vibrator';
import { BusinessError } from '@ohos.base';
import { window } from '@kit.ArkUI';
import common from '@ohos.app.ability.common';
import resourceManager from '@ohos.resourceManager';

declare type Any = ESObject;

export interface MakepadXComponentInterface{
  onCreate(ark_ts: object):void;
  handleInsertTextEvent(text:String):void;
  handleDeleteLeftEvent(length: number):void;
  handleKeyboardStatus(isOpen:boolean, keyboardHeight:number):void;
  // Audio callbacks
  handleAudioData?(data: ArrayBuffer):void;
  // Permission callbacks
  handlePermissionResult?(permission: string, granted: boolean):void;
}


function getDensity(): number {
  try {
    let displayClass = display.getDefaultDisplaySync();
    console.info('Test densityDPI:' + JSON.stringify(displayClass.densityDPI));
    return displayClass.densityDPI / 160;
  } catch (exception) {
    console.error('Failed to obtain the default display object. Code: ' + JSON.stringify(exception));
    return 3;
  }
}

function getDeviceType(): string {
  let device_type: string = deviceInfo.deviceType;
  if (device_type == "") {
    console.error("deviceInfo.deviceType is empty string!")
  } else {
    console.info("Device type is " + device_type)
  }
  return device_type;
}

export class ArkGlue{
  private static instance : ArkGlue;
  static initInstance(context: common.Context) : ArkGlue {
    if(ArkGlue.instance == null) {
      ArkGlue.instance = new ArkGlue(context);
    }
      return ArkGlue.instance;
  }

  static getInstance() : ArkGlue {
    return ArkGlue.instance;
  }

  context: common.Context;

  deviceType = getDeviceType();
  osFullName = deviceInfo.osFullName;
  displayDensity = getDensity();
  resMgr : resourceManager.ResourceManager;
  filesDir : string;
  cacheDir : string;
  tempDir : string;

  keyboardHeight : number = 1020;
  xComponentContext : MakepadXComponentInterface | undefined = undefined;

  private inputMethodController : inputMethod.InputMethodController;
  private textConfig: inputMethod.TextConfig;
  private imcFlag = false;

  // Audio-related properties
  private audioRenderer: audio.AudioRenderer | null = null;
  private audioCapturer: audio.AudioCapturer | null = null;
  private isAudioOutputStarted = false;
  private isAudioInputStarted = false;

  // Camera-related properties
  private cameraManager: camera.CameraManager | null = null;
  private cameraInput: camera.CameraInput | null = null;
  private captureSession: camera.CaptureSession | null = null;
  private videoOutput: camera.VideoOutput | null = null;
  private isVideoInputStarted = false;
  private videoSurfaceId: string = '';

  // Network monitoring
  private netConn: network.NetManager | null = null;
  private networkStateChangeListener: number = -1;

  constructor(context: common.Context) {
    this.context = context;
    this.resMgr = this.context.resourceManager;
    this.filesDir = this.context.filesDir;
    this.cacheDir = this.context.cacheDir;
    this.tempDir = this.context.tempDir;
    this.inputMethodController = inputMethod.getController();
    this.textConfig = {
      inputAttribute: {
        textInputType: 0,
        enterKeyType: 1
      }
    };
  }

  showKeyBoard(): void {
    this.showTextInput();
  }

  hideKeyBoard(): void {
    this.hideTextInput();
  }

  private async showTextInput(): Promise<void> {
    this.listenKeyboardHeightChange();
    await this.attach(true);
      if (this.imcFlag != true) {
      this.listenKeyBoardEvent();
    }
    this.inputMethodController.showTextInput().then(() => {
      console.debug("Succeeded in showing softKeyboard");
    }).catch((err: Any) => {
      console.error("Failed to show softKeyboard:" + JSON.stringify(err));
    });
  }

  private async hideTextInput(): Promise<void> {
    this.inputMethodController.hideTextInput().then(() => {
      console.debug("Succeeded in hide softKeyboard");
    }).catch((err: Any) => {
      console.error("Failed to hide softKeyboard:" + JSON.stringify(err));
    })
    this.cancelKeyboardHeightChange();
  }

  private async attach(showKeyboard: boolean): Promise<void> {
    try {
      await this.inputMethodController.attach(showKeyboard, this.textConfig);
    } catch (err) {
      console.error("Failed to attach:" + JSON.stringify(err));
    }
  }

  private listenKeyBoardEvent(): void {
    try {
      this.inputMethodController.on('insertText', (text) => {
      this.xComponentContext?.handleInsertTextEvent(text);
      console.debug("insertText: " + text);
    });
    } catch (err) {
      console.error("Failed to subscribe insertText:" + JSON.stringify(err));
      this.cancelListenKeyBoardEvent();
      return;
    }

    try {
      this.inputMethodController.on('deleteLeft', (length) => {
        this.xComponentContext?.handleDeleteLeftEvent(length);
        console.debug("deleteLeft, length:" + JSON.stringify(length));
      })
    } catch (err) {
      console.error("Failed to subscribe deleteLeft:" + JSON.stringify(err));
      this.cancelListenKeyBoardEvent();
      return;
    }

    try {
      this.inputMethodController.on('sendKeyboardStatus', (state) => {
        if (state == inputMethod.KeyboardStatus.HIDE) {
          this.xComponentContext?.handleKeyboardStatus(false, 0);
          this.inputMethodController.detach();
          this.cancelListenKeyBoardEvent();
        }
        console.debug("sendKeyboardStatus, state:" + JSON.stringify(state));
      })
    } catch (err) {
      console.error("Failed to subscribe sendKeyboardStatus:" + JSON.stringify(err));
      this.cancelListenKeyBoardEvent();
      return;
    }

    console.debug("listenKeyBoardEvent success");
    this.imcFlag = true;
  }

  private cancelListenKeyBoardEvent(): void {
    this.inputMethodController.off('insertText');
    this.inputMethodController.off('deleteLeft');
    this.inputMethodController.off('sendKeyboardStatus');
    this.imcFlag = false;
  }

  private listenKeyboardHeightChange() {
    window.getLastWindow(getContext(this)).then(currentWindow => {
      try {
        currentWindow.on('keyboardHeightChange', (data) => {
          console.info('Succeeded in enabling the listener for keyboard height changes. Data: ' + JSON.stringify(data));
          if (data != 0) {
            this.xComponentContext?.handleKeyboardStatus(true,data);
          }
        });
      } catch (exception) {
        console.error(`Failed to enable the listener for keyboard height changes. Cause code: ${exception.code}, message: ${exception.message}`);
      }
    })
  }

  private cancelKeyboardHeightChange() {
    window.getLastWindow(getContext(this)).then(currentWindow => {
      try {
        currentWindow.off('keyboardHeightChange');
      } catch (exception) {
        console.error(`Failed to enable the listener for keyboard height changes. Cause code: ${exception.code}, message: ${exception.message}`);
      }
    })
  }

  // Audio output functions
  async startAudioOutput(sampleRate: number, channels: number): Promise<void> {
    if (this.isAudioOutputStarted) {
      console.warn("Audio output already started");
      return;
    }

    try {
      const audioStreamInfo: audio.AudioStreamInfo = {
        samplingRate: sampleRate as audio.AudioSamplingRate,
        channels: channels as audio.AudioChannel,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
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
      await this.audioRenderer.start();
      this.isAudioOutputStarted = true;
      console.info("Audio output started successfully");
    } catch (err) {
      console.error("Failed to start audio output: " + JSON.stringify(err));
    }
  }

  async stopAudioOutput(): Promise<void> {
    if (!this.isAudioOutputStarted || !this.audioRenderer) {
      console.warn("Audio output not started");
      return;
    }

    try {
      await this.audioRenderer.stop();
      await this.audioRenderer.release();
      this.audioRenderer = null;
      this.isAudioOutputStarted = false;
      console.info("Audio output stopped successfully");
    } catch (err) {
      console.error("Failed to stop audio output: " + JSON.stringify(err));
    }
  }

  async writeAudioData(data: ArrayBuffer): Promise<void> {
    if (!this.isAudioOutputStarted || !this.audioRenderer) {
      console.warn("Audio output not started, cannot write data");
      return;
    }

    try {
      await this.audioRenderer.write(data);
    } catch (err) {
      console.error("Failed to write audio data: " + JSON.stringify(err));
    }
  }

  // Audio input functions
  async startAudioInput(sampleRate: number, channels: number): Promise<void> {
    if (this.isAudioInputStarted) {
      console.warn("Audio input already started");
      return;
    }

    try {
      const audioStreamInfo: audio.AudioStreamInfo = {
        samplingRate: sampleRate as audio.AudioSamplingRate,
        channels: channels as audio.AudioChannel,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };

      const audioCapturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      };

      const audioCapturerOptions: audio.AudioCapturerOptions = {
        streamInfo: audioStreamInfo,
        capturerInfo: audioCapturerInfo
      };

      this.audioCapturer = await audio.createAudioCapturer(audioCapturerOptions);
      await this.audioCapturer.start();
      this.isAudioInputStarted = true;
      console.info("Audio input started successfully");
    } catch (err) {
      console.error("Failed to start audio input: " + JSON.stringify(err));
    }
  }

  async stopAudioInput(): Promise<void> {
    if (!this.isAudioInputStarted || !this.audioCapturer) {
      console.warn("Audio input not started");
      return;
    }

    try {
      await this.audioCapturer.stop();
      await this.audioCapturer.release();
      this.audioCapturer = null;
      this.isAudioInputStarted = false;
      console.info("Audio input stopped successfully");
    } catch (err) {
      console.error("Failed to stop audio input: " + JSON.stringify(err));
    }
  }

  async readAudioData(): Promise<ArrayBuffer> {
    if (!this.isAudioInputStarted || !this.audioCapturer) {
      console.warn("Audio input not started");
      return new ArrayBuffer(0);
    }

    try {
      const bufferSize = 4096;
      const buffer = await this.audioCapturer.read(bufferSize, true);
      return buffer;
    } catch (err) {
      console.error("Failed to read audio data: " + JSON.stringify(err));
      return new ArrayBuffer(0);
    }
  }

  // Clipboard functions
  copyToClipboard(text: string): void {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text));
      console.info("Text copied to clipboard: " + text);
    } catch (err) {
      console.error("Failed to copy to clipboard: " + JSON.stringify(err));
    }
  }

  async pasteFromClipboard(): Promise<string> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = await systemPasteboard.getData();
      const text = pasteData.getPrimaryText();
      console.info("Text pasted from clipboard: " + text);
      return text;
    } catch (err) {
      console.error("Failed to paste from clipboard: " + JSON.stringify(err));
      return "";
    }
  }

  // Permission functions
  async requestMicrophonePermission(requestId: number): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const permissions = ['ohos.permission.MICROPHONE'];

      const result = await atManager.requestPermissionsFromUser(this.context, permissions);
      const granted = result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;

      console.info("Microphone permission request result: " + granted);

      // Notify native layer about the permission result
      if (this.xComponentContext?.handlePermissionResult) {
        this.xComponentContext.handlePermissionResult('microphone', granted);
      }

      return granted;
    } catch (err) {
      console.error("Failed to request microphone permission: " + JSON.stringify(err));
      return false;
    }
  }

  async checkPermission(permission: string): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const grantStatus = await atManager.checkAccessToken(this.context.applicationInfo.accessTokenId, permission);
      const granted = grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      console.info("Permission check for " + permission + ": " + granted);
      return granted;
    } catch (err) {
      console.error("Failed to check permission: " + JSON.stringify(err));
      return false;
    }
  }

  // Camera functions
  async startVideoInput(width: number, height: number, frameRate: number): Promise<void> {
    if (this.isVideoInputStarted) {
      console.warn("Video input already started");
      return;
    }

    try {
      this.cameraManager = camera.getCameraManager(this.context);

      // Get available cameras
      const cameras = await this.cameraManager.getSupportedCameras();
      if (cameras.length === 0) {
        console.error("No cameras available");
        return;
      }

      // Create camera input
      this.cameraInput = this.cameraManager.createCameraInput(cameras[0]);

      // Create video output
      const videoProfile = {
        frameRateRange: { min: frameRate, max: frameRate },
        size: { width: width, height: height },
        format: camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP
      };

      this.videoOutput = {
        surfaceId: this.videoSurfaceId,
      };

      // Create capture session
      this.captureSession = this.cameraManager.createCaptureSession();

      // Begin configuration
      this.captureSession.beginConfig();

      // Add inputs and outputs
      this.captureSession.addInput(this.cameraInput);
      this.captureSession.addOutput(this.videoOutput);

      // Commit configuration
      await this.captureSession.commitConfig();

      // Start camera
      await this.cameraInput.open();
      await this.captureSession.start();

      this.isVideoInputStarted = true;
      console.info("Video input started successfully");
    } catch (err) {
      console.error("Failed to start video input: " + JSON.stringify(err));
    }
  }

  async stopVideoInput(): Promise<void> {
    if (!this.isVideoInputStarted) {
      console.warn("Video input not started");
      return;
    }

    try {
      if (this.captureSession) {
        await this.captureSession.stop();
      }
      if (this.cameraInput) {
        await this.cameraInput.close();
      }
      if (this.captureSession) {
        await this.captureSession.release();
      }
      if (this.cameraInput) {
        await this.cameraInput.release();
      }

      this.cameraInput = null;
      this.captureSession = null;
      this.videoOutput = null;
      this.isVideoInputStarted = false;
      console.info("Video input stopped successfully");
    } catch (err) {
      console.error("Failed to stop video input: " + JSON.stringify(err));
    }
  }

  setVideoSurfaceId(surfaceId: string): void {
    this.videoSurfaceId = surfaceId;
    console.info("Video surface ID set: " + surfaceId);
  }

  // Notification functions
  async showNotification(title: string, content: string): Promise<void> {
    try {
      const notificationRequest: notificationManager.NotificationRequest = {
        id: 1,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: content,
          }
        }
      };

      await notificationManager.publish(notificationRequest);
      console.info("Notification published: " + title);
    } catch (err) {
      console.error("Failed to show notification: " + JSON.stringify(err));
    }
  }

  async cancelNotification(id: number): Promise<void> {
    try {
      await notificationManager.cancel(id);
      console.info("Notification cancelled: " + id);
    } catch (err) {
      console.error("Failed to cancel notification: " + JSON.stringify(err));
    }
  }

  // Network monitoring functions
  startNetworkMonitoring(): void {
    try {
      this.netConn = network.createNetConnection(this.context);

      this.netConn.register((error, data) => {
        if (error) {
          console.error("Network registration failed: " + JSON.stringify(error));
          return;
        }

        console.info("Network state changed: " + JSON.stringify(data));

        // Notify native layer about network state change
        if (this.xComponentContext?.handleNetworkChange) {
          this.xComponentContext.handleNetworkChange(data);
        }
      });

      this.networkStateChangeListener = this.netConn.on('netStatus', (data) => {
        console.info("Network status: " + JSON.stringify(data));
      });

      console.info("Network monitoring started");
    } catch (err) {
      console.error("Failed to start network monitoring: " + JSON.stringify(err));
    }
  }

  stopNetworkMonitoring(): void {
    try {
      if (this.netConn && this.networkStateChangeListener !== -1) {
        this.netConn.off('netStatus', this.networkStateChangeListener);
        this.netConn.unregister();
        this.networkStateChangeListener = -1;
        console.info("Network monitoring stopped");
      }
    } catch (err) {
      console.error("Failed to stop network monitoring: " + JSON.stringify(err));
    }
  }

  getNetworkState(): network.NetConnectionType {
    if (this.netConn) {
      const netType = this.netConn.getNetType();
      console.info("Current network type: " + netType);
      return netType;
    }
    return network.NetConnectionType.NET_TYPE_NONE;
  }

  // File picker functions
  async showFilePicker(title: string): Promise<string | null> {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const options: picker.DocumentSelectOptions = {
        maxSelectNumber: 1,
        fileSuffixFilters: ['*'],
      };

      const result = await documentPicker.select(options);
      if (result.length > 0) {
        console.info("File selected: " + result[0]);
        return result[0];
      }
      return null;
    } catch (err) {
      console.error("Failed to show file picker: " + JSON.stringify(err));
      return null;
    }
  }

  async showFileSaver(defaultName: string): Promise<string | null> {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const options: picker.DocumentSaveOptions = {
        fileName: defaultName,
        fileSuffixChoices: ['txt', 'json', 'md'],
      };

      const result = await documentPicker.save(options);
      console.info("File saved: " + result);
      return result;
    } catch (err) {
      console.error("Failed to show file saver: " + JSON.stringify(err));
      return null;
    }
  }

  // Vibration functions
  async vibrate(duration: number): Promise<void> {
    try {
      await vibrator.startVibration({
        type: 'time',
        duration: duration,
      });
      console.info("Vibration started: " + duration + "ms");
    } catch (err) {
      console.error("Failed to vibrate: " + JSON.stringify(err));
    }
  }

  async stopVibration(): Promise<void> {
    try {
      await vibrator.stopVibration();
      console.info("Vibration stopped");
    } catch (err) {
      console.error("Failed to stop vibration: " + JSON.stringify(err));
    }
  }

  // Vibrate with pattern
  async vibratePattern(pattern: number[]): Promise<void> {
    try {
      await vibrator.startVibration({
        type: 'preset',
        effectId: 'haptic.clock.timer',
        count: pattern.length,
      });
      console.info("Vibration with pattern started");
    } catch (err) {
      console.error("Failed to vibrate with pattern: " + JSON.stringify(err));
    }
  }

}

export interface XComponentAttrs {
  id: string;
  type: number;
  libraryname: string;
}