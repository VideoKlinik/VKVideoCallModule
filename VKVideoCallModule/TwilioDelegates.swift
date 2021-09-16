//
//  TwilioDelegates.swift
//  Sante
//
//  Created by Caglar Cakar on 25.08.2019.
//  Copyright © 2019 Dijital Garaj. All rights reserved.
//

import Foundation
import TwilioVideo
import CallKit
//import Firebase

// MARK: TVIRoomDelegate
extension MeetingViewController : RoomDelegate {
    func roomDidConnect(room: Room) {
        // At the moment, this example only supports rendering one Participant at a time.
        logMessage(messageText: "Connected to room \(room.name) as \(room.localParticipant?.identity ?? "")")

        // This example only renders 1 RemoteVideoTrack at a time. Listen for all events to decide which track to render.
        if room.remoteParticipants.count > 0 {
            self.state = .connected
            for remoteParticipant in room.remoteParticipants {
                remoteParticipant.delegate = self
            }
        }
        else {
            self.state = .waitingForParticipant
        }

        let cxObserver = callKitCallController.callObserver
        let calls = cxObserver.calls

        // Let the call provider know that the outgoing call has connected
        if let uuid = room.uuid, let call = calls.first(where:{$0.uuid == uuid}) {
            if call.isOutgoing {
                callKitProvider.reportOutgoingCall(with: uuid, connectedAt: nil)
            }
        }
        
        self.callKitCompletionHandler!(true)
    }
    
    func waitingUI(){
        self.infoLabel.text = NSLocalizedString("connecting", comment: "") //"Bağlanıyor..."
        self.soundTimer?.invalidate()
//        self.soundTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true, block: { (execute) in
//            self.audioPlayer.play()
//        })
    }
    
    func connectedUI(){
//        self.audioPlayer.stop()
        self.soundTimer?.invalidate()
        self.infoLabel.text = ""
    }
    
    func disConnectedUI(){
        let reason = CXCallEndedReason.remoteEnded
        self.callKitProvider.reportCall(with: self.callUUID, endedAt: nil, reason: reason)
        self.performEndCallAction(uuid: self.callUUID)
        self.dismiss(animated: true) {
                self.delegate?.meetingEnded()
        }
    }
    
    func roomDidDisconnect(room: Room, error: Error?) {
        logMessage(messageText: "Disconnected from room \(room.name), error = \(String(describing: error))")
//        self.state = .disConnected
        if !self.userInitiatedDisconnect, let uuid = room.uuid, let error = error {
            var reason = CXCallEndedReason.remoteEnded

            if (error as NSError).code != TwilioVideoSDK.Error.roomRoomCompletedError.rawValue {
                reason = .failed
            }

            self.callKitProvider.reportCall(with: uuid, endedAt: nil, reason: reason)
        }
//        self.room = nil
//        self.callKitCompletionHandler = nil
//        self.userInitiatedDisconnect = false
    }
    
    func roomDidFailToConnect(room: Room, error: Error) {
        logMessage(messageText: "Failed to connect to room with error: \(error.localizedDescription)")
        self.state = .failedToConnect
        self.infoLabel.text = NSLocalizedString("failed-to-connect-please-try-again!", comment: "") //"Bağlantı kurulamadı, lütfen tekrar deneyin!"
        
        self.callKitCompletionHandler!(false)
        self.room = nil
//        self.showRoomUI(inRoom: false)
    }
    
    func roomIsReconnecting(room: Room, error: Error) {
        logMessage(messageText: "Reconnecting to room \(room.name), error = \(String(describing: error))")
    }
    
    func roomDidReconnect(room: Room) {
        logMessage(messageText: "Reconnected to room \(room.name)")
    }
    
    func participantDidConnect(room: Room, participant: RemoteParticipant) {
        participant.delegate = self
        setVideoViewsUI()
        logMessage(messageText: "Participant \(participant.identity) connected with \(participant.remoteAudioTracks.count) audio and \(participant.remoteVideoTracks.count) video tracks")
        delegate?.participantDidConnect(connectedParticipantId: participant.identity)
//        if User.currentUser.type == .doctor, appointment?.isParticipant != true, !participant.identity.contains("2nd"), !participant.identity.contains("Terc.") {
//            Analytics.logEvent("doctor_meeting_start", parameters: nil)
//        }
    }
    
    func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        logMessage(messageText: "Room \(room.name), Participant \(participant.identity) disconnected")
        setVideoViewsUI()
        delegate?.participantDidDisconnect(disconnectedParticipantId: participant.identity, remainingParticipantsIds: room.remoteParticipants.map({ $0.identity }))
//        if (!participant.identity.contains("2nd") && !participant.identity.contains("Terc.")) || (participant.identity.contains("2nd") && User.currentUser.type != .doctor && !room.remoteParticipants.contains(where: { !$0.identity.contains("Ter.") && $0.identity != appointment?.patientName && !$0.identity.contains("2nd") })) {
//            self.state = .disConnected
//            self.room = nil
//            self.callKitCompletionHandler = nil
//            self.userInitiatedDisconnect = false
//        }
    }
    
    func interpreterDidDisconnect(_ participant:RemoteParticipant) {
        if participant.identity == self.remoteParticipant?.identity {
            cleanupRemoteParticipant(participant, from: self.remoteView)
            self.remoteParticipant = nil
            self.remoteViewContainer.isHidden = true
        }
        else if participant.identity == self.remoteParticipant2?.identity {
            cleanupRemoteParticipant(participant, from: self.remoteView2)
            self.remoteParticipant2 = nil
            self.remoteView2Container.isHidden = true
        }
        else if participant.identity == self.remoteParticipant3?.identity {
            cleanupRemoteParticipant(participant, from: self.remoteView3)
            self.remoteParticipant3 = nil
            self.remoteView3Container.isHidden = true
        }
    }
    
    func dominantSpeakerDidChange(room: Room, participant: RemoteParticipant?) {
        guard participant != nil, participant != self.dominantSpeaker, !isPinned else { return }
        changeSpeaker(participant: participant!)
    }
    
    func changeSpeaker(participant:RemoteParticipant) {
        localVideoTrack?.removeRenderer(self.mainView)
        if self.dominantSpeaker != nil {
            cleanupRemoteParticipant(self.dominantSpeaker!, from: self.mainView)
        }
        let newVideoPublications = participant.remoteVideoTracks
        for publication in newVideoPublications {
            if let subscribedVideoTrack = publication.remoteTrack, publication.isTrackSubscribed {
                subscribedVideoTrack.addRenderer(self.mainView)
                self.dominantSpeaker = participant
                setBorder(for: participant)
                return
            }
        }
    }
}

// MARK: TVIRemoteParticipantDelegate
extension MeetingViewController : RemoteParticipantDelegate {
    
    func remoteParticipantDidPublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has offered to share the video Track.
        
        logMessage(messageText: "Participant \(participant.identity) published video track")
    }
    
    func remoteParticipantDidUnpublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has stopped sharing the video Track.
        
        logMessage(messageText: "Participant \(participant.identity) unpublished video track")
    }
    
    func remoteParticipantDidPublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // Remote Participant has offered to share the audio Track.
        
        logMessage(messageText: "Participant \(participant.identity) published audio track")
    }
    
    func remoteParticipantDidUnpublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) unpublished audio track")
    }
    
    func didSubscribeToVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // The LocalParticipant is subscribed to the RemoteParticipant's video Track. Frames will begin to arrive now.

        logMessage(messageText: "Subscribed to \(publication.trackName) video track for Participant \(participant.identity)")
        delegate?.didSubscribeToVideoTrack(participantId: participant.identity)
//        if participant.identity.contains("Terc."), User.currentUser.type == .patient {
//            Analytics.setUserProperty("1", forName: FirebaseUserProperty.hasMeetingWithInterpreter.rawValue)
//            OneSignalManager.sendTag(.hasMeetingWithInterpreter)
//        }

        if self.remoteParticipant == nil || self.remoteParticipant2 == nil || self.remoteParticipant3 == nil {
            if self.state != .connected {
                self.state = .connected
            }
            _ = renderRemoteParticipant(participant: participant)
            setVideoViewsUI()
        }
    }
    
    func didUnsubscribeFromVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
        // remote Participant's video.

        logMessage(messageText: "Unsubscribed from \(publication.trackName) video track for Participant \(participant.identity)")
        interpreterDidDisconnect(participant)
        if nameLabel.text != getCurrentUserName()/*User.currentUser.displayName*/ {
            if let dParticipant = room?.dominantSpeaker, dParticipant.identity != participant.identity {
                changeSpeaker(participant: dParticipant)
            }
            else if let rParticipant = room?.remoteParticipants.first(where: { $0.identity != participant.identity }) {
                changeSpeaker(participant: rParticipant)
            }
        }
    }
    
    func didSubscribeToAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's audio now.
        
        logMessage(messageText: "Subscribed to audio track for Participant \(participant.identity)")
    }
    
    func didUnsubscribeFromAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
        // remote Participant's audio.
        
        logMessage(messageText: "Unsubscribed from audio track for Participant \(participant.identity)")
    }
    
    func remoteParticipantDidEnableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) enabled video track")
    }
    
    func remoteParticipantDidDisableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) disabled video track")
    }
    
    func remoteParticipantDidEnableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) enabled audio track")
    }
    
    func remoteParticipantDidDisableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) disabled audio track")
    }

    func didFailToSubscribeToAudioTrack(publication: RemoteAudioTrackPublication, error: Error, participant: RemoteParticipant) {
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) audio track, error = \(String(describing: error))")
    }

    func didFailToSubscribeToVideoTrack(publication: RemoteVideoTrackPublication, error: Error, participant: RemoteParticipant) {
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) video track, error = \(String(describing: error))")
    }
}

class Settings: NSObject {
    
    let supportedAudioCodecs: [AudioCodec] = [IsacCodec(),
                                              OpusCodec(),
                                              PcmaCodec(),
                                              PcmuCodec(),
                                              G722Codec()]
    
    let supportedVideoCodecs: [VideoCodec] = [Vp8Codec(),
                                              Vp8Codec(simulcast: true),
                                              H264Codec(),
                                              Vp9Codec()]
    
    var audioCodec: AudioCodec?
    var videoCodec: VideoCodec?
    
    var maxAudioBitrate = UInt()
    var maxVideoBitrate = UInt()
    
    func getEncodingParameters() -> EncodingParameters?  {
        if maxAudioBitrate == 0 && maxVideoBitrate == 0 {
            return nil;
        } else {
            return EncodingParameters(audioBitrate: maxAudioBitrate,
                                         videoBitrate: maxVideoBitrate)
        }
    }
    
    private override init() {
        // Can't initialize a singleton
    }
    
    // MARK: Shared Instance
    static let shared = Settings()
}
