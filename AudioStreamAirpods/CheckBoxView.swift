//
//  CheckBoxView.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/20.
//

import SwiftUI

struct CheckBoxView: View {
    @Binding var checked: Bool

    var body: some View {
        Image(systemName: checked ? "checkmark.square.fill" : "square")
            .foregroundColor(checked ? .accentColor : .secondary)
    }
}

struct CheckBoxView_Previews: PreviewProvider {
    static var previews: some View {
        CheckBoxView(checked: .constant(false))
    }
}
