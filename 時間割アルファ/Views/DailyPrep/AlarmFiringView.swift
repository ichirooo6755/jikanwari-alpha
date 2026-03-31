import SwiftUI

// MARK: - AlarmFiringView
// フルスクリーン・止めるまで鳴り続けるアラーム画面

struct AlarmFiringView: View {
    @Bindable var alarmVM: AlarmViewModel
    let schedule: DepartureSchedule

    @State private var pulseAnimation = false
    @State private var shakeCount = 0

    var body: some View {
        ZStack {
            // 背景
            Color.red.opacity(0.9)
                .ignoresSafeArea()
                .overlay(
                    // パルスアニメーション
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .scaleEffect(pulseAnimation ? 2.5 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)
                        .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false),
                                   value: pulseAnimation)
                )

            VStack(spacing: 40) {
                Spacer()

                // アラームアイコン
                Image(systemName: "alarm.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(shakeCount % 2 == 0 ? -10 : 10))
                    .animation(.easeInOut(duration: 0.1).repeatCount(6, autoreverses: true),
                               value: shakeCount)

                // 時刻表示
                Text(schedule.departureTime.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    Text("出発まであと40分！")
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(.white)
                    if !schedule.homeStationName.isEmpty && !schedule.arrivalStationName.isEmpty {
                        Text("\(schedule.homeStationName) → \(schedule.arrivalStationName)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Spacer()

                // 止めるボタン（大きく、目立つ）
                Button {
                    alarmVM.stopAlarm()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 48))
                        Text("アラームを止める")
                            .font(.title2).fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(Color.white)
                    .foregroundStyle(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 40)
                    .shadow(color: .black.opacity(0.3), radius: 20)
                }

                Text("ボタンを押してアラームを止めてください")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            pulseAnimation = true
            // シェイクアニメーション
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                shakeCount += 1
            }
        }
        .statusBarHidden(true)
    }
}
