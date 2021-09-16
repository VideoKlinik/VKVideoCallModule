//
//  VKVideoCallModule.swift
//  VKVideoCallModule
//
//  Created by Mehmet Akif Şengül on 15.09.2021.
//

import Foundation
import CallKit
import UIKit

public protocol MeetingDelegate {
    func meetingScreenLoaded()
    func meetingEnded()
    func suggestButtonTapped()
    func participantDidConnect(connectedParticipantId: String)
    func participantDidDisconnect(disconnectedParticipantId: String, remainingParticipantsIds: [String])
    func connectionTimedOut()
    func didSubscribeToVideoTrack(participantId: String)
}

public enum UserType {
    case patient
    case primaryDoctor
    case secondaryDoctor
    case interpreter
}

final public class VKVideoCallModule {
    class func startMeeting(from viewController: UIViewController, accessToken: String, roomName: String, callUUID: UUID, callKitProvider: CXProvider, isRecording: Bool = false, suggestButtonEnabled: Bool = false, willEndAutomatically: Bool = false, userType: UserType, patientName: String, primaryDoctorName: String, secondaryDoctorName: String? = nil, interpreterName: String? = nil) {
        let meetingVC = UIStoryboard(name: "Meeting", bundle: nil).instantiateViewController(withIdentifier: "MeetingViewController") as! MeetingViewController
        meetingVC.delegate = viewController as? MeetingDelegate
        meetingVC.accessToken = accessToken
        meetingVC.roomName = roomName
        meetingVC.callUUID = callUUID
        meetingVC.callKitProvider = callKitProvider
        meetingVC.isRecording = isRecording
        meetingVC.suggestButtonEnabled = suggestButtonEnabled
        meetingVC.willEndAutomatically = willEndAutomatically
        meetingVC.userType = userType
        meetingVC.patientName = patientName
        meetingVC.doctorName = primaryDoctorName
        meetingVC.secondaryDoctorName = secondaryDoctorName
        meetingVC.interpreterName = interpreterName
        meetingVC.modalPresentationStyle = .fullScreen
        viewController.present(meetingVC, animated: true, completion: nil)
    }
}