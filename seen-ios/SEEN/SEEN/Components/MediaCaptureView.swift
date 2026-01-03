import SwiftUI
import AVFoundation
import PhotosUI

// MARK: - Media Type Selection

enum CaptureMediaType: String, CaseIterable {
    case photo = "Photo"
    case video = "Video"
    case audio = "Voice Note"
    
    var icon: String {
        switch self {
        case .photo: return "camera.fill"
        case .video: return "video.fill"
        case .audio: return "mic.fill"
        }
    }
}

struct CapturedMedia {
    let type: CaptureMediaType
    let image: UIImage?
    let videoURL: URL?
    let audioURL: URL?
    
    var mediaType: MediaType {
        switch type {
        case .photo: return .PHOTO
        case .video: return .VIDEO
        case .audio: return .AUDIO
        }
    }
}

// MARK: - Media Capture View

struct MediaCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMediaType: CaptureMediaType = .photo
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var capturedVideoURL: URL?
    @State private var isRecordingAudio = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordedAudioURL: URL?
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    
    let onCapture: (CapturedMedia) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Media type selector
                Picker("Media Type", selection: $selectedMediaType) {
                    ForEach(CaptureMediaType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                Spacer()
                
                // Preview area
                previewArea
                
                Spacer()
                
                // Capture controls
                captureControls
            }
            .padding()
            .navigationTitle("Add Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                PhotosPicker(selection: .constant(nil)) {
                    Text("Select")
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraCaptureView(
                    mediaType: selectedMediaType,
                    onCapture: { image, videoURL in
                        if let image = image {
                            capturedImage = image
                        }
                        if let url = videoURL {
                            capturedVideoURL = url
                        }
                    }
                )
            }
            .onAppear {
                setupAudioSession()
            }
            .onDisappear {
                stopRecording()
            }
        }
    }
    
    @ViewBuilder
    private var previewArea: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray6))
            .frame(height: 300)
            .overlay {
                switch selectedMediaType {
                case .photo:
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 300)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No photo selected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                case .video:
                    if capturedVideoURL != nil {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.seenGreen)
                            Text("Video recorded")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack {
                            Image(systemName: "video")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No video recorded")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                case .audio:
                    VStack(spacing: 16) {
                        if isRecordingAudio {
                            // Recording indicator
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 12, height: 12)
                                Text("Recording...")
                                    .foregroundStyle(.red)
                            }
                            
                            Text(formatDuration(recordingDuration))
                                .font(.system(.title, design: .monospaced))
                                .foregroundStyle(.primary)
                            
                            // Waveform animation placeholder
                            HStack(spacing: 4) {
                                ForEach(0..<10, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.seenGreen)
                                        .frame(width: 4, height: CGFloat.random(in: 10...40))
                                        .animation(.easeInOut(duration: 0.2).repeatForever(), value: recordingDuration)
                                }
                            }
                        } else if recordedAudioURL != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.seenGreen)
                            Text("Voice note recorded")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "waveform")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Tap to record")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
    }
    
    @ViewBuilder
    private var captureControls: some View {
        switch selectedMediaType {
        case .photo:
            HStack(spacing: 20) {
                Button {
                    showingImagePicker = true
                } label: {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassSecondary)
                
                Button {
                    showingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassPrimary)
            }
            
            if capturedImage != nil {
                Button {
                    confirmCapture()
                } label: {
                    Label("Use Photo", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassPrimary)
            }
            
        case .video:
            Button {
                showingCamera = true
            } label: {
                Label(capturedVideoURL == nil ? "Record Video" : "Re-record", systemImage: "video.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassPrimary)
            
            if capturedVideoURL != nil {
                Button {
                    confirmCapture()
                } label: {
                    Label("Use Video", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassPrimary)
            }
            
        case .audio:
            if isRecordingAudio {
                Button {
                    stopRecording()
                } label: {
                    Label("Stop Recording", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button {
                    startRecording()
                } label: {
                    Label(recordedAudioURL == nil ? "Start Recording" : "Re-record", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassPrimary)
            }
            
            if recordedAudioURL != nil && !isRecordingAudio {
                Button {
                    confirmCapture()
                } label: {
                    Label("Use Voice Note", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassPrimary)
            }
        }
    }
    
    // MARK: - Audio Recording
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func startRecording() {
        let audioFilename = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecordingAudio = true
            recordingDuration = 0
            
            // Start timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordingDuration += 0.1
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        guard let recorder = audioRecorder, recorder.isRecording else {
            isRecordingAudio = false
            return
        }
        
        recorder.stop()
        recordedAudioURL = recorder.url
        isRecordingAudio = false
    }
    
    private func confirmCapture() {
        let media: CapturedMedia
        
        switch selectedMediaType {
        case .photo:
            media = CapturedMedia(type: .photo, image: capturedImage, videoURL: nil, audioURL: nil)
        case .video:
            media = CapturedMedia(type: .video, image: nil, videoURL: capturedVideoURL, audioURL: nil)
        case .audio:
            media = CapturedMedia(type: .audio, image: nil, videoURL: nil, audioURL: recordedAudioURL)
        }
        
        onCapture(media)
        dismiss()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Camera Capture View

struct CameraCaptureView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
    let mediaType: CaptureMediaType
    let onCapture: (UIImage?, URL?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        
        switch mediaType {
        case .photo:
            picker.mediaTypes = ["public.image"]
            picker.cameraCaptureMode = .photo
        case .video:
            picker.mediaTypes = ["public.movie"]
            picker.cameraCaptureMode = .video
            picker.videoMaximumDuration = 30 // 30 second limit
            picker.videoQuality = .typeMedium
        case .audio:
            // Audio uses AVAudioRecorder, not camera
            break
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCaptureView
        
        init(_ parent: CameraCaptureView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image, nil)
            } else if let videoURL = info[.mediaURL] as? URL {
                parent.onCapture(nil, videoURL)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    MediaCaptureView { media in
        print("Captured: \(media.type)")
    }
}
