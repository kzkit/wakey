//
//  GlassStyles.swift
//  Wakey
//
//  Created by Claude on 11/10/2026.
//

import AppKit
import SwiftUI

// Liquid Glass helpers for macOS 26+. Every helper falls back to the look Wakey had before Liquid Glass,
// so call sites stay free of availability checks and macOS 15 renders exactly as it did. The exceptions are
// `menuPanelWindowBackground` and `menuPanelBackground`, which give every supported macOS the same translucent menu material.

extension View {
	/// The background behind the menu bar panel's content. On macOS 26+ the panel already draws the system
	/// background, and another material on top would flatten it.
	@ViewBuilder
	func windowContentBackground() -> some View {
		if #available(macOS 26.0, *) {
			self
		} else {
			background(.regularMaterial)
		}
	}
	
	/// Fills a whole window with the translucent material of the menu bar panel, blurring the desktop behind it,
	/// so a window opened from the menu matches it. Unlike the helpers around it, it looks the same before macOS 26.
	func menuPanelWindowBackground() -> some View {
		containerBackground(for: .window) {
			MenuPanelMaterial()
		}
	}
	
	/// The same material for content hosted in a window AppKit created, where SwiftUI doesn't own the window
	/// background. The window needs a full-size content view so the material also fills the title bar.
	func menuPanelBackground() -> some View {
		background {
			MenuPanelMaterial()
				.ignoresSafeArea()
		}
	}
	
	/// The main action of a small button group: prominent glass on macOS 26+.
	@ViewBuilder
	func primaryActionButtonStyle() -> some View {
		if #available(macOS 26.0, *) {
			buttonStyle(.glassProminent)
		} else {
			buttonStyle(.borderedProminent)
		}
	}
	
	/// A secondary action next to a primary one: glass on macOS 26+, the default button style before.
	@ViewBuilder
	func secondaryActionButtonStyle() -> some View {
		if #available(macOS 26.0, *) {
			buttonStyle(.glass)
		} else {
			self
		}
	}
	
	/// Fills a rounded highlight behind the view, inset from its edges. On macOS 26+ the corners are concentric
	/// with the enclosing container (window, panel or `containerShape`), but never rounder than `minimumConcentricRadius`.
	@ViewBuilder
	func rowHighlight<S: ShapeStyle>(
		_ style: S,
		cornerRadius: CGFloat,
		minimumConcentricRadius: CGFloat? = nil,
		horizontalInset: CGFloat,
		verticalInset: CGFloat = 0
	) -> some View {
		if #available(macOS 26.0, *) {
			background(
				ConcentricRectangle(corners: .concentric(minimum: .fixed(minimumConcentricRadius ?? cornerRadius)), isUniform: true)
					.fill(style)
					.padding(.horizontal, horizontalInset)
					.padding(.vertical, verticalInset)
			)
		} else {
			background(
				RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
					.fill(style)
					.padding(.horizontal, horizontalInset)
					.padding(.vertical, verticalInset)
			)
		}
	}
	
	/// The rounded background of a group of rows. On macOS 26+ it uses the system fill, which strengthens with
	/// Increase Contrast, and becomes the container shape that `rowHighlight`s inside it are concentric with.
	@ViewBuilder
	func groupBackground(cornerRadius: CGFloat, fallbackOpacity: Double) -> some View {
		let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
		
		if #available(macOS 26.0, *) {
			background(shape.fill(SystemFill.tertiary.color(fallbackOpacity: fallbackOpacity)))
				.clipShape(shape)
				.containerShape(shape)
		} else {
			background(shape.fill(Color.primary.opacity(fallbackOpacity)))
				.clipShape(shape)
		}
	}
	
	/// Styles a capsule toggle chip's label and background. On macOS 26+ the chip is tinted interactive glass when
	/// selected and untinted glass when not. Place chips that sit together in a `GlassGroup`.
	func chipStyle(isSelected: Bool, tint: Color) -> some View {
		modifier(ChipStyle(isSelected: isSelected, tint: tint))
	}
}

private struct ChipStyle: ViewModifier {
	let isSelected: Bool
	let tint: Color
	
	@Environment(\.controlActiveState) private var controlActiveState
	@Environment(\.colorScheme) private var colorScheme
	
	func body(content: Content) -> some View {
		if #available(macOS 26.0, *) {
			// Glass drops its tint while the window is inactive, which would leave selected and unselected chips the
			// same grey. A selected chip then becomes a strong neutral pill instead (like a selected segment keeps a
			// clearly stronger fill than the track), so the selection still reads without relying on colour.
			let isWindowActive = controlActiveState != .inactive
			
			content
				.foregroundStyle(chipForeground(isWindowActive: isWindowActive))
				.background {
					if isSelected && !isWindowActive {
						Capsule(style: .continuous)
							.fill(Color(nsColor: .secondaryLabelColor))
					}
				}
				.glassEffect(isSelected && isWindowActive ? .regular.tint(tint).interactive() : .regular.interactive(), in: .capsule)
		} else {
			content
				.foregroundStyle(isSelected ? Color.white : Color.primary)
				.background(
					Capsule(style: .continuous)
						.fill(isSelected ? tint : Color.primary.opacity(0.06))
				)
		}
	}
	
	private func chipForeground(isWindowActive: Bool) -> Color {
		guard isSelected else { return .primary }
		guard !isWindowActive else { return .white }
		
		// The neutral pill is mid grey in light mode and light grey in dark mode, so dark text reads best on both.
		return colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : .primary
	}
}

/// The menu material blended with what's behind the window. It stays active while the window is in the background,
/// like the menu bar panel, rather than turning opaque.
private struct MenuPanelMaterial: NSViewRepresentable {
	func makeNSView(context: Context) -> NSVisualEffectView {
		let view = NSVisualEffectView()
		view.material = .menu
		view.blendingMode = .behindWindow
		view.state = .active
		return view
	}
	
	func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Neutral fills for highlights and grouped backgrounds. On macOS 26+ these are the system fill colors, which adapt
/// to the appearance and Increase Contrast; before that they're the fixed primary-color opacities Wakey always used.
enum SystemFill {
	case primary
	case secondary
	case tertiary
	
	func color(fallbackOpacity: Double) -> Color {
		guard #available(macOS 26.0, *) else {
			return Color.primary.opacity(fallbackOpacity)
		}
		
		switch self {
		case .primary: return Color(nsColor: .systemFill)
		case .secondary: return Color(nsColor: .secondarySystemFill)
		case .tertiary: return Color(nsColor: .tertiarySystemFill)
		}
	}
}

/// Groups nearby glass elements so they render and morph together on macOS 26+. Before that it's transparent.
struct GlassGroup<Content: View>: View {
	var spacing: CGFloat?
	@ViewBuilder let content: Content
	
	var body: some View {
		if #available(macOS 26.0, *) {
			GlassEffectContainer(spacing: spacing) {
				content
			}
		} else {
			content
		}
	}
}
