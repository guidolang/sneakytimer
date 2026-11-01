import AudioToolbox
import Foundation

protocol AlarmService {
    func timerDidComplete()
}

struct SystemAlarmService: AlarmService {
    func timerDidComplete() {
        for round in 0..<2 {
            let delay = TimeInterval(round)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                AudioServicesPlaySystemSound(1005)
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
}
