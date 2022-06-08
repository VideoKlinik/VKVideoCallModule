//
//  MeetingViewController.swift
//  Sante
//
//  Created by Caglar Cakar on 22.08.2019.
//  Copyright © 2019 Dijital Garaj. All rights reserved.
//

import UIKit
import TwilioVideo
import CallKit
import AVFoundation
//import Firebase

class MeetingViewController: UIViewController {

    enum UIState {
        case connecting
        case connected
        case failedToConnect
        case waitingForParticipant
        case reConnecting
        case participantDisconnected
        case disConnected
    }
    
    var state:UIState = .connecting {
        didSet{
            
            switch state {
            case .connecting:
//                LogManager.log("UI State connecting")
                self.disConnectedUI()
                self.infoLabel.text = NSLocalizedString("connecting", comment: "")//"Bağlantı kuruluyor."
            break
            case .connected:
//                LogManager.log("UI State connected")
                self.connectionTimer?.invalidate()
                self.connectedUI()
            break
            case .waitingForParticipant:
//                LogManager.log("UI State waitingForParticipant")
                self.waitingUI()
            break
            case .reConnecting:
//                LogManager.log("UI State reConnecting")
                self.waitingUI()
            break
            case .participantDisconnected:
                //dismiss
//                LogManager.log("UI State participantDisconnected")
                //self.infoLabel.text = NSLocalizedString("meeting-completed", comment: "") //"Görüşme tamamlandı."
            break
            case .failedToConnect:
//                LogManager.log("UI State failedToConnect")
                self.disConnectedUI()
                self.infoLabel.text = NSLocalizedString("failed-to-connect!", comment: "") //"Bağlantı kurulamadı!"
            break
            case .disConnected:
//                LogManager.log("UI State disConnected")
                self.disConnectedUI()
                self.infoLabel.text = NSLocalizedString("connection-ended", comment: "") //"Bağlantı sonlandı."
            break
            }
        }
    }
    
    var accessToken:String = ""
    var roomName:String = ""
    var isRecording = false
    var suggestButtonEnabled = false
    var willEndAutomatically = false
    var patientName: String!
    var doctorName: String!
    var secondaryDoctorName: String?
    var interpreterName: String?
    var userType: VKUserType!
    
    var room: Room?
    
    var audioDevice: DefaultAudioDevice = DefaultAudioDevice()
    var camera: CameraSource?
    var localVideoTrack: LocalVideoTrack?
    var localAudioTrack: LocalAudioTrack?
    var remoteParticipant: RemoteParticipant? {
        didSet {
            participantNameLabel.text = getName(for: remoteParticipant)
        }
    }
    var remoteParticipant2: RemoteParticipant? {
        didSet {
            participant2NameLabel.text = getName(for: remoteParticipant2)
        }
    }
    var remoteParticipant3: RemoteParticipant? {
        didSet {
            participant3NameLabel.text = getName(for: remoteParticipant3)
        }
    }
    var dominantSpeaker: RemoteParticipant? {
        didSet {
            nameLabel.superview?.superview?.isHidden = false
            nameLabel.text = getName(for: dominantSpeaker)
        }
    }
    var callUUID: UUID!
    // CallKit components
    var callKitProvider: CXProvider!
    var callKitCallController: CXCallController
    var callKitCompletionHandler: ((Bool)->Swift.Void?)? = nil
    var userInitiatedDisconnect: Bool = false
    var isPinned = false
    
    @IBOutlet weak var mainView: VideoView!
    @IBOutlet weak var mainViewTopConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var videoStackView: UIStackView!
    @IBOutlet weak var videoStackViewTopConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var remoteViewContainer: UIView!
    @IBOutlet weak var remoteView: VideoView!
    @IBOutlet weak var participantNameLabel: UILabel!
    @IBOutlet weak var remoteFocusButton: UIButton!
    
    @IBOutlet weak var remoteView2Container: UIView!
    @IBOutlet weak var remoteView2: VideoView!
    @IBOutlet weak var participant2NameLabel: UILabel!
    
    @IBOutlet weak var remoteView3Container: UIView!
    @IBOutlet weak var remoteView3: VideoView!
    @IBOutlet weak var participant3NameLabel: UILabel!
    
    @IBOutlet weak var previewContainer: UIView!
    @IBOutlet weak var previewView: VideoView!
    @IBOutlet weak var userNameLabel: UILabel!
    
    @IBOutlet var videoViews: [VideoView]!
    @IBOutlet var videoContainerViews: [UIView]!
    
    //UI
    @IBOutlet weak var buttonsView: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var recordView: UIView!
    
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var pinButton: UIButton!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var suggestButton: UIButton!
    @IBOutlet weak var stopVideoButton: UIButton!
    
    var animationTimer:Timer?
    var soundTimer:Timer?
    var targetApp: TargetApp!
    
//    var audioPlayer:AVAudioPlayer!
    
    var delegate:MeetingDelegate?
    var isCameraOn = true
    private var connectionTimer:Timer?
    
    var showDuration = false
    var duration:Int = 0 {
        didSet {
            guard durationLabel != nil else {
                return
            }
            let (h,m,s) = secondsToHoursMinutesSeconds(seconds: duration)
            let seconds = s < 10 ? "0\(s)":"\(s)"
            let minutes = m < 10 ? "0\(m)":"\(m)"
            let hours = h < 10 ? "0\(h)":"\(h)"
            durationLabel.text = hours == "00" ? "\(minutes):\(seconds)":"\(hours):\(minutes):\(seconds)"
        }
    }
    private var durationTimer:Timer?
    private var didEnterBackgorundDate:Date?
    private var nameLabels = [UILabel]()
    
    required init?(coder aDecoder: NSCoder) {
        
//        LogManager.log("MeetingViewController_init")
        
//        let configuration = CXProviderConfiguration(localizedName: "Sante")
//        configuration.maximumCallGroups = 1
//        configuration.maximumCallsPerCallGroup = 1
//        configuration.supportsVideo = true
//        configuration.supportedHandleTypes = [.generic]
//        if let callKitIcon = UIImage(named: "ST-logo") {
//            configuration.iconTemplateImageData = callKitIcon.pngData()
//        }

//        callKitProvider = self.appDelegate.provider!
        callKitCallController = CXCallController()
//        self.audioDevice = 
        super.init(coder: aDecoder)
    }

    deinit {
        // CallKit has an odd API contract where the developer must call invalidate or the CXProvider is leaked.
//        LogManager.log("MeetingViewController_deinit")
        callKitProvider.invalidate()
        self.room?.disconnect()
        self.localVideoTrack = nil
        self.camera = nil
        self.room = nil
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
//        self.audioPlayer.stop()
        self.animationTimer?.invalidate()
        self.soundTimer?.invalidate()
        self.connectionTimer?.invalidate()
        self.durationTimer?.invalidate()
        
        camera?.stopCapture()
        
        UIApplication.shared.isIdleTimerDisabled = false
//        appDelegate.hasMeeting = false
        
        let reason = CXCallEndedReason.remoteEnded
        self.callKitProvider.reportCall(with: self.callUUID, endedAt: nil, reason: reason)
        
        self.performEndCallAction(uuid: self.callUUID)
        if let room = self.room {
            self.logMessage(messageText: "Attempting to disconnect from room \(room.name)")
            self.userInitiatedDisconnect = true
            self.room?.disconnect()
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        LogManager.log("Meeting did load")
        delegate?.meetingScreenLoaded()//Analytics.setScreenName("meeting_page", screenClass: nil)
        callKitProvider.setDelegate(self, queue: nil)
        self.infoLabel.text = ""
        self.userNameLabel.text = getCurrentUserName()//User.currentUser.displayName
        self.startPreview()
        
        for videoView in videoViews {
            videoView.superview?.layer.cornerRadius = 6
        }
        
        for containerView in videoContainerViews {
            containerView.layer.cornerRadius = 6
        }
        
        nameLabels = [userNameLabel, participantNameLabel, participant2NameLabel, participant3NameLabel]
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.mainView.addGestureRecognizer(tap)
    
        self.recordView.isHidden = !isRecording
        
        suggestButton?.layer.cornerRadius = 16
        suggestButton?.isHidden = !suggestButtonEnabled
        
//        let sound = Bundle.main.path(forResource: "outgoingCall", ofType: "caf")
//        do{
//            self.audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: sound!))
////            self.audioPlayer.numberOfLoops = 5
//            self.audioPlayer.volume = 10
//            self.audioPlayer.prepareToPlay()
//        }
//        catch {
//            print (error)
//        }
        
        // Do any additional setup after loading the view.
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { (_) in
            if self.localVideoTrack != nil {
                self.room?.localParticipant?.unpublishVideoTrack(self.localVideoTrack!)
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { (_) in
            if self.localVideoTrack != nil {
                self.room?.localParticipant?.publishVideoTrack(self.localVideoTrack!)
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { (_) in
            if self.userType == .primaryDoctor {
                self.didEnterBackgorundDate = Date()
                self.durationTimer?.invalidate()
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { (_) in
            if self.userType == .primaryDoctor {
                let backgroundDuration = Int(Date().timeIntervalSince(self.didEnterBackgorundDate ?? Date()))
                if self.willEndAutomatically {
                    if backgroundDuration > self.duration {
                        self.close(nil)
                    }
                    else {
                        self.duration -= backgroundDuration
                        self.startDurationTimer()
                    }
                }
                else {
                    self.duration += backgroundDuration
                    self.startDurationTimer()
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        LogManager.log("Meeting will appear")
        UIApplication.shared.isIdleTimerDisabled = true
        nameLabel.text = doctorName
        switch targetApp {
        case .asm:
            buttonsView.layer.cornerRadius = 16
        case .videoKlinik:
            buttonsView.layer.cornerRadius = buttonsView.bounds.height / 2
            nameLabel.superview?.layer.cornerRadius = (nameLabel.superview?.bounds.height ?? 0) / 2
        case .iComed:
            buttonsView.layer.cornerRadius = buttonsView.bounds.height / 2
            nameLabel.superview?.layer.cornerRadius = (nameLabel.superview?.bounds.height ?? 0) / 2
        case .none:
            break
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 90, repeats: false, block: { (_) in
            self.delegate?.connectionTimedOut()//self.showError(NSLocalizedString("failed-to-connect!", comment: ""))
            self.close(nil)
        })
        
        if showDuration {
            startDurationTimer()
        }
    }
    
    private func getName(for participant:RemoteParticipant?) -> String? {
        if participant?.identity.contains("Terc.") ?? false || participant?.identity.contains("2nd") ?? false {
            return participant?.identity
        }
        else {
            if !(userType == .secondaryDoctor) {
                return userType == .patient ? doctorName:patientName
            }
            else {
                if participant?.identity == patientName {
                    return patientName
                }
                else {
                    return doctorName
                }
            }
        }
    }
    
    func getCurrentUserName() -> String? {
        switch userType {
        case .patient:
            return patientName
        case .primaryDoctor:
            return doctorName
        case .secondaryDoctor:
            return secondaryDoctorName
        case .interpreter:
            return interpreterName
        default:
            return nil
        }
    }
    
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (_) in
            if self.willEndAutomatically == true {
                self.duration -= 1
                if self.duration <= 0 {
                    self.close(nil)
                    return
                }
            }
            else {
                self.duration += 1
            }
        })
    }
    
    private func secondsToHoursMinutesSeconds (seconds : Int) -> (Int, Int, Int) {
        return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }
    
    func setBorder(for participant:RemoteParticipant?) {
        videoContainerViews.forEach { (view) in
            view.backgroundColor = UIColor(hex: "BFC7E0")
        }
        nameLabels.forEach { (label) in
            label.textColor = .black
            label.superview?.backgroundColor = .white
        }
        var dominantView:UIView
        var dominantUserNameLabel: UILabel
        if participant == nil {
            dominantView = previewContainer
            dominantUserNameLabel = userNameLabel
        }
        else if participant == remoteParticipant {
            dominantView = remoteViewContainer
            dominantUserNameLabel = participantNameLabel
        }
        else if participant == remoteParticipant2 {
            dominantView = remoteView2Container
            dominantUserNameLabel = participant2NameLabel
        }
        else {
            dominantView = remoteView3Container
            dominantUserNameLabel = participant3NameLabel
        }
        if targetApp != .asm {
            dominantView.backgroundColor = UIColor(hex: "376CE9")
            dominantUserNameLabel.textColor = .white
            dominantUserNameLabel.superview?.backgroundColor = UIColor(hex: "376CE9")
        }
    }

    func startPreview() {
        #if targetEnvironment(simulator)
            return
        #endif
        
        let frontCamera = CameraSource.captureDevice(position: .front)
        let backCamera = CameraSource.captureDevice(position: .back)
        
        if (frontCamera != nil || backCamera != nil) {
            // Preview our local camera track in the local video preview view.
            camera = CameraSource(delegate: self)
            localVideoTrack = LocalVideoTrack.init(source: camera!, enabled: true, name: "Camera")
            
            // Add renderer to video track for local preview
            if isCameraOn {
                localVideoTrack!.addRenderer(self.previewView)
            }
            logMessage(messageText: "Video track created")
            
            if (frontCamera != nil && backCamera != nil) {
                // We will flip camera on tap.
                let tap = UITapGestureRecognizer(target: self, action: #selector(MeetingViewController.flipCamera))
                self.previewView.addGestureRecognizer(tap)
            }
            
            camera!.startCapture(device: frontCamera != nil ? frontCamera! : backCamera!) { (captureDevice, videoFormat, error) in
                if let error = error {
                    self.logMessage(messageText: "Capture failed with error.\ncode = \((error as NSError).code) error = \(error.localizedDescription)")
                } else {
                    self.previewView.shouldMirror = (captureDevice.position == .front)
                }
            }
        }
        else {
            self.logMessage(messageText:"No front or back capture device found!")
        }
        self.performRoomConnect(uuid: self.callUUID, roomName: self.roomName) { (success) in
            
        }
    }

    @IBAction func suggestButtonAction(_ sender: Any) {
        delegate?.suggestButtonTapped()
    }
    
    @IBAction func stopVideoButtonAction(_ sender: Any) {
        if let participant = room?.localParticipant, let videoTrack = localVideoTrack {
            if isCameraOn {
                videoTrack.removeRenderer(previewView)
                stopVideoButton.setImage(R.image.cameraOn(), for: .normal)
                participant.unpublishVideoTrack(videoTrack)
            }
            else {
                videoTrack.addRenderer(previewView)
                stopVideoButton.setImage(R.image.cameraOff(), for: .normal)
                participant.publishVideoTrack(videoTrack)
            }
            isCameraOn = !isCameraOn
            if !isCameraOn, videoTrack.renderers.count > 0 {
                focusButtonAction(remoteFocusButton)
            }
        }
    }
    
    @IBAction func mute(_ sender: Any) {
        if let room = room, let uuid = room.uuid, let localAudioTrack = self.localAudioTrack {
            let isMuted = localAudioTrack.isEnabled
            let muteAction = CXSetMutedCallAction(call: uuid, muted: isMuted)
            let transaction = CXTransaction(action: muteAction)
            
            if isMuted {
                self.localAudioTrack!.isEnabled = false
                let imageName = targetApp == .asm ? "asm-unmute-icon":"ST-UnMute"
                self.muteButton.setImage(UIImage(named: imageName), for: .normal)
            }else{
                let imageName = targetApp == .asm ? "asm-mute-icon":"ST-Mute"
                self.localAudioTrack!.isEnabled = true
                self.muteButton.setImage(UIImage(named: imageName), for: .normal)
            }
            
            
            callKitCallController.request(transaction)  { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.logMessage(messageText: "SetMutedCallAction transaction request failed: \(error.localizedDescription)")
                        return
                    }
                    self.logMessage(messageText: "SetMutedCallAction transaction request successful")
                }
            }
        }
    }
    @IBAction func speaker(_ sender: Any) {
        
    }
    @IBAction func close(_ sender: Any?) {
//        LogManager.log("ending call callUUID: \(self.appDelegate.callUUID)")
//        LogManager.log("room UUID: \(self.room!.uuid)")
//
        
        camera?.stopCapture()
        
        let reason = CXCallEndedReason.remoteEnded
        self.callKitProvider.reportCall(with: self.callUUID, endedAt: nil, reason: reason)
        
        self.performEndCallAction(uuid: self.callUUID)
        if let room = self.room {
            self.logMessage(messageText: "Attempting to disconnect from room \(room.name)")
            self.userInitiatedDisconnect = true
            self.room?.disconnect()
        }
        self.dismiss(animated: true) {
            self.delegate?.meetingEnded()
        }
        
    }
    @IBAction func flipCamera() {
        var newDevice: AVCaptureDevice?
        
        if let camera = self.camera, let captureDevice = camera.device {
            if captureDevice.position == .front {
                newDevice = CameraSource.captureDevice(position: .back)
            } else {
                newDevice = CameraSource.captureDevice(position: .front)
            }
            
            if let newDevice = newDevice {
                camera.selectCaptureDevice(newDevice) { (captureDevice, videoFormat, error) in
                    if let error = error {
                        self.logMessage(messageText: "Error selecting capture device.\ncode = \((error as NSError).code) error = \(error.localizedDescription)")
                    } else {
                        self.previewView.shouldMirror = (captureDevice.position == .front)
                        if self.previewContainer.backgroundColor == UIColor(hex: "286AF1"), captureDevice.position == .front {
                            self.mainView.shouldMirror = true
                        }
                        else {
                            self.mainView.shouldMirror = false
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func focusButtonAction(_ sender: UIButton) {
        guard (room?.remoteParticipants.count ?? 0) > 0 else {
            return
        }
        localVideoTrack?.removeRenderer(self.mainView)
        if sender.tag == 0 {
            guard isCameraOn else {
                return
            }
            nameLabel.text = getCurrentUserName()//User.currentUser.displayName
            if self.dominantSpeaker != nil {
                cleanupRemoteParticipant(self.dominantSpeaker!, from: self.mainView)
            }
            localVideoTrack?.addRenderer(self.mainView)
            if room?.remoteParticipants.count == 1 {
                previewContainer.isHidden = true
                remoteViewContainer.isHidden = false
            }
            self.mainView.shouldMirror = camera?.device?.position == .front
            if targetApp != .asm {
                setBorder(for: nil)
            }
        }
        else {
            self.mainView.shouldMirror = false
            var participant:RemoteParticipant
            if sender.tag == 1 {
                participant = self.remoteParticipant!
                if room?.remoteParticipants.count == 1 {
                    previewContainer.isHidden = false
                    remoteViewContainer.isHidden = true
                }
            }
            else if sender.tag == 2 {
                participant = self.remoteParticipant2!
            }
            else {
                participant = self.remoteParticipant3!
            }
            changeSpeaker(participant: participant)
        }
        if pinButton != nil, !isPinned {
            pinButtonAction(pinButton)
        } else {
            
        }
    }
    
    @IBAction func pinButtonAction(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        isPinned = sender.isSelected
        if !isPinned, let participant = room?.dominantSpeaker {
            changeSpeaker(participant: participant)
        }
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        if buttonsView.isHidden {
            self.buttonsView.isHidden = !self.buttonsView.isHidden
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        else {
            UIView.animate(withDuration: 0.3) {
                self.buttonsView.isHidden = !self.buttonsView.isHidden
            }
        }
    }
    
    func muteAudio(isMuted: Bool) {
//        if let localAudioTrack = self.localAudioTrack {
//            localAudioTrack.isEnabled = !isMuted
//            
//            // Update the button title
//            if (!isMuted) {
//                self.muteButton.setTitle("Mute", for: .normal)
//                self.muteButton.isSelected = false
//            } else {
//                self.muteButton.setTitle("Unmute", for: .normal)
//                self.muteButton.isSelected = false
//            }
//        }
    }
    
    func logMessage(messageText: String) {
//        LogManager.log(messageText)
    }
    
    //Mark - Animations
    
//    func connectingAnimation(){
//        self.profileView.isHidden = false
//        self.profileView.alpha = 1
//
//        self.glowViewWidthConstraint.constant = 160
//        UIView.animate(withDuration: 0.05, animations: {
//            self.glowView.layer.cornerRadius = 80
//            self.view.layoutIfNeeded()
//        }) { (completed) in
//            self.glowViewWidthConstraint.constant = 170
//            UIView.animate(withDuration: 0.05, animations: {
//                self.glowView.layer.cornerRadius = 85
//                self.view.layoutIfNeeded()
//            }) { (completed) in
//                self.glowViewWidthConstraint.constant = 140
//                UIView.animate(withDuration: 0.1, animations: {
//                    self.glowView.layer.cornerRadius = 70
//                    self.view.layoutIfNeeded()
//                }) { (completed) in
//
//                    self.glowViewWidthConstraint.constant = 160
//                    UIView.animate(withDuration: 0.05, animations: {
//                        self.glowView.layer.cornerRadius = 80
//                        self.view.layoutIfNeeded()
//                    }) { (completed) in
//                        self.glowViewWidthConstraint.constant = 170
//                        UIView.animate(withDuration: 0.05, animations: {
//                            self.glowView.layer.cornerRadius = 85
//                            self.view.layoutIfNeeded()
//                        }) { (completed) in
//                            self.glowViewWidthConstraint.constant = 140
//                            UIView.animate(withDuration: 0.8, animations: {
//                                self.glowView.layer.cornerRadius = 70
//                                self.view.layoutIfNeeded()
//                            }) { (completed) in
//
//                            }
//                        }
//                    }
//
//                }
//            }
//        }
//    }
    
//    private func endProfileViewAnimation(){
//        UIView.animate(withDuration: 0.8, animations: {
//           self.profileView.alpha = 0
//        }) { (completed) in
//
//        }
//    }
    
    func renderRemoteParticipant(participant : RemoteParticipant) -> Bool {
        // This example renders the first subscribed RemoteVideoTrack from the RemoteParticipant.
        let videoPublications = participant.remoteVideoTracks
        for publication in videoPublications {
            if let subscribedVideoTrack = publication.remoteTrack,
                publication.isTrackSubscribed {
                if self.remoteParticipant == nil {
                    subscribedVideoTrack.addRenderer(self.remoteView)
                    self.remoteParticipant = participant
                    if self.room?.remoteParticipants.count == 1 {
                        self.remoteViewContainer.isHidden = true
                        if !isPinned, targetApp != .asm {
                            self.setBorder(for: participant)
                        }
                    }
                    else {
                        self.remoteViewContainer.isHidden = false
                    }
                }
                else if self.remoteParticipant2 == nil {
                    self.remoteViewContainer.isHidden = false
                    self.remoteView2Container.isHidden = false
                    subscribedVideoTrack.addRenderer(self.remoteView2)
                    self.remoteParticipant2 = participant
                }
                else if self.remoteParticipant3 == nil {
                    self.remoteViewContainer.isHidden = false
                    self.remoteView3Container.isHidden = false
                    subscribedVideoTrack.addRenderer(self.remoteView3)
                    self.remoteParticipant3 = participant
                }
                if (self.dominantSpeaker == nil || self.room?.remoteParticipants.count == 1 && !isPinned) || (self.dominantSpeaker == participant && previewContainer.backgroundColor != UIColor(hex: "286AF1")) {
                    changeSpeaker(participant: participant)
                }
                return true
            }
        }
        return false
    }
    
    func cleanupRemoteParticipant(_ participant : RemoteParticipant, from videoView:VideoView) {
        let videoPublications = participant.remoteVideoTracks
        for publication in videoPublications {
            if let subscribedVideoTrack = publication.remoteTrack {
                subscribedVideoTrack.removeRenderer(videoView)
            }
        }
    }
    
    func setVideoViewsUI() {
        if (self.room?.remoteParticipants.count ?? 0) > 1 {
            if videoStackViewTopConstraint.constant != 2 {
                mainViewTopConstraint.constant = videoStackView.bounds.height + 4 + view.safeAreaInsets.top
                videoStackViewTopConstraint.constant = 2
                previewContainer.isHidden = false
                remoteViewContainer.isHidden = false
            }
        }
        else {
            if mainViewTopConstraint.constant != 0 {
                mainViewTopConstraint.constant = 0
                videoStackViewTopConstraint.constant = 30
                if nameLabel.text == getCurrentUserName()/*User.currentUser.displayName*/ {
                    previewContainer.isHidden = true
                    remoteViewContainer.isHidden = false
                }
                else {
                    previewContainer.isHidden = false
                    remoteViewContainer.isHidden = true
                }
            }
        }
    }
}
// MARK: TVIVideoViewDelegate
extension MeetingViewController : VideoViewDelegate {
    func videoViewDimensionsDidChange(view: VideoView, dimensions: CMVideoDimensions) {
        self.view.setNeedsLayout()
    }
}

// MARK: TVICameraSourceDelegate
extension MeetingViewController : CameraSourceDelegate {
    func cameraSourceDidFail(source: CameraSource, error: Error) {
        logMessage(messageText: "Camera source failed with error: \(error.localizedDescription)")
    }
}

private extension UIColor {
    /**
     Creates an UIColor from HEX String in "#363636" format
     
     - parameter hexString: HEX String in "#363636" format
     - returns: UIColor from HexString
     */
    convenience init(hex: String) {
        
        let hexString: String       = (hex as NSString).trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner                 = Scanner(string: hexString as String)
        
        if hexString.hasPrefix("#") {
            scanner.scanLocation = 1
        }
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)
        
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        
        let red   = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue  = CGFloat(b) / 255.0
        self.init(red:red, green:green, blue:blue, alpha:1)
    }
    
    /// Create UIColor from RGB values with optional transparency.
    ///
    /// - Parameters:
    ///   - red: red component.
    ///   - green: green component.
    ///   - blue: blue component.
    ///   - transparency: optional transparency value (default is 1)
    convenience init(red: Int, green: Int, blue: Int, transparency: CGFloat = 1) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        var trans: CGFloat {
            if transparency > 1 {
                return 1
            } else if transparency < 0 {
                return 0
            } else {
                return transparency
            }
        }
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: trans)
    }
}

private extension UIView {
    func roundCorners(_ corners: UIRectCorner, radius: CGFloat) {
        let cornerRadii = CGSize(width: radius, height: radius)
        let maskPath = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: cornerRadii)
        let shape = CAShapeLayer()
        shape.path = maskPath.cgPath
        layer.mask = shape
    }
}
