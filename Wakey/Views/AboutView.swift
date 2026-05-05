//
//  AboutView.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 06/05/2026.
//

import AppKit
import SwiftUI

struct AboutView: View {
	var body: some View {
		VStack(spacing: 14) {
			Spacer(minLength: 8)
			
			Image(nsImage: NSApp.applicationIconImage)
				.resizable()
				.scaledToFit()
				.frame(width: 88, height: 88)
				.shadow(color: .black.opacity(0.18), radius: 8, y: 3)
			
			VStack(spacing: 6) {
				Text(appName)
					.font(.system(size: 24, weight: .bold))
					.foregroundStyle(.primary)
				
				Text(versionText)
					.font(.system(size: 14))
					.foregroundStyle(.secondary)
			}
			
			Text("Copyright © Zhen Kit Kong")
				.font(.system(size: 13))
				.foregroundStyle(.secondary)
			
			Spacer(minLength: 8)
		}
		.padding(.horizontal, 28)
		.padding(.vertical, 18)
		.frame(width: 300, height: 300)
		.background(.regularMaterial)
	}
	
	private var appName: String {
		bundleValue(for: "CFBundleDisplayName")
			?? bundleValue(for: "CFBundleName")
			?? "Wakey"
	}
	
	private var versionText: String {
		let version = bundleValue(for: "CFBundleShortVersionString") ?? "1.0"
		guard let build = bundleValue(for: "CFBundleVersion") else {
			return "Version \(version)"
		}
		
		return "Version \(version) (\(build))"
	}
	
	private func bundleValue(for key: String) -> String? {
		Bundle.main.object(forInfoDictionaryKey: key) as? String
	}
}
