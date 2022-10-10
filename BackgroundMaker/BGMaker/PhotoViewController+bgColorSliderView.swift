//
//  PhotoViewController+bgColorPickerView.swift
//  BackgroundMaker
//
//  Created by HeonJin Ha on 2022/10/03.
//

import UIKit
import SnapKit

extension PhotoViewController {

    //MARK: - ColorPicker 셋업

    
    func makeBGColorPicker() {
        
        view.addSubview(colorPickerView)
        colorPickerView.translatesAutoresizingMaskIntoConstraints = false
        colorPickerView.isHidden = true
        colorPickerView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(view)
            make.bottom.equalTo(trayView.snp.top)
            make.height.equalTo(50)
        }
    }

}
