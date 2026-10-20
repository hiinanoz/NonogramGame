import NonogramKit
import SwiftUI

/// Kedi Kutusu açılış sayfası: en yüksek puan, başla düğmesi (yarıda kalan oyun varsa devam),
/// kısa nasıl oynanır.
@MainActor
struct CatBlockHubView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme

    var body: some View {
        let blocks = model.blocks
        let style = ModeStyle.block
        VStack(spacing: 18) {
            Spacer(minLength: 8)
            Group {
                if LoopingCatAnimation.isAvailable(style.animation) {
                    LoopingCatView(name: style.animation, tapToPet: true)
                } else {
                    sampleBlocks
                }
            }
            .frame(maxHeight: 190)
            Text("Cat Block")
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(style.ink(theme))
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(Gold.foil)
                    Text(verbatim: "\(blocks.bestScore)")
                        .monospacedDigit()
                }
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                Text("Best Score")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("block.best")
            VStack(alignment: .leading, spacing: 10) {
                rule("hand.draw.fill", Text("Drag the blocks onto the board."))
                rule("line.3.horizontal", Text("Fill a row or a column to clear it."))
                rule("flame.fill", Text("Clear lines one after another for combos."))
                rule("sparkles", Text("When no block fits, you can clear the board once per game."))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(theme.surface.opacity(0.9)))
            Spacer(minLength: 8)
            VStack(spacing: 10) {
                if blocks.savedGame != nil {
                    Button {
                        router.push(.blockGame(UUID().uuidString))
                    } label: {
                        Label("Continue", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("block.continue")
                    Button {
                        startNew()
                    } label: {
                        Label("New Game", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("block.start")
                } else {
                    Button {
                        startNew()
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("block.start")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: ModeStyle.block.backgroundColors(theme), startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BirdSortRoundButton(symbol: "chevron.left") { router.pop() }
                    .accessibilityLabel(Text("Back"))
                    .accessibilityIdentifier("block.hub.back")
            }
        }
    }

    private func startNew() {
        // Yarıda kalan oyun bırakılır (puanı en yüksek puana sayılmıştı)
        model.blocks.clearSavedGame()
        router.push(.blockGame(UUID().uuidString))
    }

    private func rule(_ symbol: String, _ text: Text) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(ModeStyle.block.tint(theme))
                .frame(width: 24)
            text
                .font(.subheadline)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Kedi animasyonu gelene kadar: birkaç blok.
    private var sampleBlocks: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                CatBlockTile(color: 0, size: 44)
                CatBlockTile(color: 0, size: 44)
                CatBlockTile(color: 5, size: 44)
            }
            HStack(spacing: 4) {
                CatBlockTile(color: 3, size: 44)
                CatBlockTile(color: 2, size: 44)
                CatBlockTile(color: 5, size: 44)
            }
        }
        .padding(.top, 20)
    }
}
