import AudioToolbox
import Foundation

protocol AlarmService {
    func timerDidComplete()
}

struct SystemAlarmService: AlarmService {
    func timerDidComplete() {
        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}
