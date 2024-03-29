//
//  ViewController.swift
//  BackgroundMaker
//
//  Created by HeonJin Ha on 2022/09/05.
//

import UIKit
import SnapKit
import PhotosUI
import RxSwift
import RxCocoa
import RulerView
// import SwiftUI


enum RulerViewSwitch: String {
    case none
    case edgeBlur
    case backgroundBlur
}

/**
 `PhotoViewController는 편집할 이미지를 가져온 후 편집할 수 있는 RootVC입니다.`
 >  
 */
class MakeWallpaperViewController: UIViewController {
    
    //MARK: - [Properties] RxSwift
    var disposeBag = DisposeBag()
    
    //MARK: - 이미지 뷰 관련 초기화
    var mainImageView = UIImageView() // 메인 이미지
    let bgImageView = UIImageView() // 배경 이미지
    var sourceImage = UIImage() // 원본 이미지 아카이빙

    // 이미지 제스쳐 포인터
    lazy var imageOriginalCenter = CGPoint() // 이미지 드래그 중앙인식 포인터
    
    //MARK: - 네비게이션 바 버튼 초기화

    // 공유 버튼
    lazy var shareButton = CocoaViewBuilder.shared.makeBarButtonWithSystemImage(
        systemName: "square.and.arrow.up",
        selector: #selector(shareImageTapped),
        isHidden: false,
        target: self
    )
    
    // 뒤로가기 버튼
    lazy var backButton = CocoaViewBuilder.shared.makeBarButtonWithSystemImage(
        systemName: "arrow.backward",
        selector: #selector(backButtonTapped),
        isHidden: false,
        target: self
    )
 
    //MARK: - 하단 트레이뷰 SubViews

    // 트레이뷰 배경 구성
    let trayRootView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        view.alpha = 0.3
        
        return view
    }()
    
    let traySubView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        view.alpha = 0.0
        
        return view
    }()
    
    let traySubViewInView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        view.alpha = 0.0
        
        return view
    }()
    
    /// `Tray View` : 기능버튼들이 들어갈 하단 뷰입니다.
    lazy var bottomView: MainEditMenuView = {
        let mv = MainEditMenuView(height: 60, target: self)
        mv.parentVC = self
        return mv
    }()
    
    //MARK: 하단 서브뷰1
    /// 상하단 흐림 RulerView 초기화
    lazy var edgeRulerView: CustomRulerView = {
        let rv = CustomRulerView(title: "엣지블러")
        return rv
    }()
    
    lazy var bgRulerView: CustomRulerView = {
        let rv = CustomRulerView(title: "배경블러")
        return rv
    }()
    
    
    var bgRulerViewValue: Float = 3

    
    
    /// [배경화면 편집 뷰] 배경화면 컬러 선택기 초기화
    lazy var colorPickerView = BackgroundPickerView(target: self)
    
    
    lazy var hideViews = [self.bottomView,
                     self.edgeRulerView,
                     self.colorPickerView,
                     self.trayRootView,
                     self.traySubView,
                     self.bgRulerView,
                     self.traySubViewInView,
    ]

    // 저장 버튼
    lazy var saveButton: UIButton = {
        let action = UIAction {  _ in self.saveImage() }
        let button = CocoaViewBuilder.shared.makeButtonWithTitle(
            title: "저장", action: action, target: self)
        return button
    }()
    
    // 취소 버튼
    lazy var cancelButton: UIButton = {
        let action = UIAction { _ in self.backButtonTapped() }
        let button = CocoaViewBuilder.shared.makeButtonWithTitle(
            title: "취소", action: action, target: self)
        return button
    }()
    
    // /// `이미지 편집` 버튼
    lazy var edgeBlurButton: MenuButton = {
        let image = UIImage(named: "eraser.line.dashed.fill")!
        let title = "엣지블러"
    
        let button = MenuButton(
            target: self, image: image, title: title,
            action: #selector(edgeBlurTapped), backgroundColor: .clear)
        return button
    }()
    
    /// `백그라운드 편집` 버튼
    lazy var changeBGButton: MenuButton = {
        let image = UIImage(named: "square.2.layers.3d.bottom.filled")!
        let title = "배경레이어"
    
        // 배경편집 버튼 구성
        let button = MenuButton(
            target: self, image: image,
            title: title,
            titleColor: .white,
            action: #selector(bgLayerButtonTapped),
            backgroundColor: .clear
        )
        return button
    }()
    
    //MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        /// 네비게이션 바 버튼을 구성합니다.
        self.navigationItem.rightBarButtonItems = [shareButton] // 사진추가, 저장, 자르기 버튼

        self.navigationItem.leftBarButtonItems = [backButton] // 사진추가, 저장, 자르기 버튼
        self.navigationController?.navigationBar.backgroundColor = .clear
        
        // RxSwift
        mainImageRxSubscribe() // 편집할 이미지를 가지고 있을 Observer입니다.
        setupImageViews()
        
        // SubView : 하단 메뉴바 구성
        addBottomMenuButtons() // 하단 메뉴바 구성
        setPickedImage() // 앨범에서 선택한 이미지 불러오기

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Subview 셋업
        self.configureSubmenuBackground() // 트레이 배경뷰
        self.configureTrayView() // 트레이 뷰
        self.makeBGColorPicker() // 배경 컬러 피커뷰
        self.configureRulerViews() // 룰러 뷰
        
        
        // 이미지 관련 제스쳐
        self.addPinchGesture(selector: #selector(pinchZoomAction)) // Zoom in/out
        self.addPanGesture(selector: #selector(makeDragImageGesture)) // Move
        self.addDoubleTapRecognizer(selector: #selector(doubleTapZoomAction)) // ToubleTab

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.backgroundImageRxSubscribe()

    }

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.disposeBag = .init() // 구독 중인 모든 Observable disposeBag 비우기
        
    }
    
    /// 이미지뷰 셋업
    func setupImageViews() {
        mainImageView.translatesAutoresizingMaskIntoConstraints = false
        mainImageView.contentMode = .scaleAspectFit
        
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.isUserInteractionEnabled = false
        
        view.addSubview(bgImageView)
        bgImageView.snp.makeConstraints { make in
            make.edges.edges.equalToSuperview()
        }

        view.addSubview(mainImageView)
        mainImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    /// 불러온 이미지에 따라서 이미지 뷰의 크기를 조절합니다.
    func resizeImageView() {
        /// 이미지뷰 레이아웃
        let screenSize = UIScreen.main.bounds
        let imageSize = mainImageView.image?.size

        let imageHeight = (imageSize!.height * screenSize.width) / imageSize!.width
        let resizeHeight = (screenSize.height - imageHeight) / 2
        
        mainImageView.snp.remakeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.width.equalTo(screenSize.width)
            make.height.equalToSuperview().inset(resizeHeight)
        }
    }

    /// 바 버튼의 순서를 재배치합니다..
    func barButtonReplace(buttons: [UIBarButtonItem]) {
        self.navigationItem.rightBarButtonItems = buttons
    }
    
    /// 기능버튼이 들어갈 트레이뷰를 구성합니다.
    func configureTrayView() {

        bottomView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomView)
        
        /// 트레이 뷰 구성
        bottomView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }

    }
    
    /// 하단 메뉴 ( MainEditMenuView )에 넣을  버튼을 구성합니다.
    func addBottomMenuButtons() {
        /// 버튼들 `스택뷰`에 추가.
        bottomView.centerStackView.addArrangedSubview(edgeBlurButton)
        bottomView.centerStackView.addArrangedSubview(changeBGButton)
        bottomView.rightStackView.addArrangedSubview(saveButton)
        bottomView.leftStackView.addArrangedSubview(cancelButton)
    }
    
    //MARK: 레이어 버튼 액션
    @objc func bgLayerButtonTapped() {
        
        toggleViews(targetView: colorPickerView, bgView: traySubView, hideViews: [bgRulerView, traySubViewInView, edgeRulerView])
        
    }
    
    //MARK: 엣지 블러 버튼 액션
    @objc func edgeBlurTapped() {
        
        toggleViews(targetView: edgeRulerView, bgView: traySubView, hideViews: [colorPickerView, traySubViewInView, bgRulerView])
        
    }
    
    func toggleViews(targetView: UIView, bgView: UIView, hideViews: [UIView], duration: CGFloat = 0.2) {

        if targetView.alpha == 0 { // 타겟뷰가 안보이면
            UIView.animate(withDuration: duration) {
                // 타겟 뷰 및 타겟 배경 뷰 보이게
                targetView.alpha = 1
                bgView.alpha = 0.4
                
                // 상관 없는 뷰는 숨기기
                hideViews.forEach { hideView in
                    hideView.alpha = 0
                }
            }
        } else {
            targetView.alpha = 0
            bgView.alpha = 0
            
            hideViews.forEach { hideView in
                hideView.alpha = 0
            }
        }
        
    }
    


    
    
    //MARK: - ImageView, PHPicker(ImagePicker) 셋업
    
    /// 선택한 이미지를 가져오고 뷰에 반영합니다.
    func setPickedImage() {
        RxImageViewModel.shared.mainImageSubject
            .subscribe { [weak self] (image) in
                guard let image = image else { return }
                
                DispatchQueue.main.async {
                    self?.mainImageView.transform = CGAffineTransform(scaleX: 1, y: 1) // 선택한 이미지의 크기를 초기화합니다.
                    self?.bgImageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1) // 백그라운드 이미지의 크기를 초기화합니다. (결과물 비네팅방지를 위해 1.1배로 설정)
                    RxImageViewModel.shared.sourcePhotoSubject.onNext(image)
                    self?.sourceImage = image
                }
            } onError: { error in
                print("getPickedImage 이미지 가져오기 에러 :\(error.localizedDescription) ")
            } onCompleted: {
                print("selectedPhoto Get Completed")
            } onDisposed: {
                print("selectedPhoto Disposed")
            }.disposed(by: disposeBag)
    }
 
    /// 사진을 디바이스에 저장하는 메소드입니다.
    func saveImageToAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(imageSaveHandler), nil)
        let newWallpaper = Wallpaper(context: CoreData.shared.persistentContainer.viewContext)
        let imgData = image.pngData()
        newWallpaper.wallpaper = imgData
        newWallpaper.createdDate = Date()
        newWallpaper.id = UUID()
        
        WallpaperCoreData.shared.wallpapers.append(newWallpaper)
        WallpaperCoreData.shared.saveData()
    }
    
    //MARK: - App Configure
    /// 앱의 접근권한 확인을 위해 앱의 설정 화면으로 가는 딥링크를 만듭니다.
    func openUserAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    //MARK: - Selectors
    
    /// 사진 저장 처리결과를 Alert로 Present합니다.
    @objc func imageSaveHandler(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        
        /// 앨범에 사진 저장이 성공 / 실패 했을 때 알럿을 띄웁니다.
        let alert = UIAlertController(title: "", message: "", preferredStyle: .alert)
        let apply = UIAlertAction(title: "확인", style: .default) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.dismiss(animated: true)
            }
        }
        
        if let error = error {
            /// 사진 접근권한 확인을 위해 앱의 설정 화면으로 가는 딥링크를 만듭니다.
            let setting = UIAlertAction(title: "설정하기", style: .default) { _ in
                self.openUserAppSettings()
            }
            alert.addAction(setting)
            print("ERROR: \(error)")
            alert.title = "저장 실패"
            alert.message = "사진 저장이 실패했습니다. 아래 설정버튼을 눌러 사진 접근 권한을 확인해주세요."
            return
        } else {
            

            
            alert.addAction(apply)
            alert.title = "저장 성공"
            alert.message = "앨범에서 저장된 사진을 확인하세요."

        }
        present(alert, animated: true)
    }
    

    /// 현재 뷰를 캡쳐하고 그 이미지를 앨범에 저장하는 메소드입니다.
    @objc func saveImage() {
 
        if let image = EditImageModel.shared
            .takeScreenViewCapture(withoutView: self.hideViews, target: self) {
            
            saveImageToAlbum(image: image)
            
        }
    }
    
    /// 현재 뷰를 캡쳐하고 그 이미지를 공유합니다.
    @objc func shareImageTapped() {
        if let image = EditImageModel.shared.takeScreenViewCapture(withoutView: self.hideViews, target: self) {
            EditImageModel.shared.shareImageButton(image: image, target: self)
        }
    }
        
    /// 닫기 버튼을 탭했을때의 동작입니다. 사용자에게 편집을 중단 할 것인지 묻는 알림창을 띄웁니다.
    @objc func backButtonTapped() {
        let alert = UIAlertController(title: "이미지의 편집을 중단하고 첫화면으로 이동합니다.", message: "만약 저장하지 않으셨다면 우선 저장해주세요.", preferredStyle: .alert)
        let apply = UIAlertAction(title: "첫 화면 가기", style: .default) { [weak self] _ in
            RxImageViewModel.shared.mainImageSubject.onNext(nil)
            RxImageViewModel.shared.backgroundImageSubject.onNext(nil)
            self?.dismiss(animated: true)
        }
        
        let cancel = UIAlertAction(title: "취소", style: .default)
        alert.addAction(apply)
        alert.addAction(cancel)
        present(alert, animated: true)
        
    }

//MARK: - 구독 메소드 Subscribers

    // 메인 이미지 구독
    func mainImageRxSubscribe() {
        
        RxImageViewModel.shared.mainImageObservable.subscribe { [weak self] (image) in
            print("mainImageObservable : 이미지를 가져옵니다.")

            DispatchQueue.main.async {
                self?.mainImageView.image = image
                
                if image != nil {
                    self?.resizeImageView()
                }
                
                self?.sourceImage = image!
                let bgImage = EditImageModel.shared.makeBlurImage(image: image!, radius: 15)
                RxImageViewModel.shared.backgroundImageSubject.onNext(bgImage)

            }
        } onError: { error in
            print("mainImage Error : \(error.localizedDescription)")
        } onCompleted: {
            print("mainImage Completed")
        } onDisposed: {
            print("mainImage Disposed")
        }.dispose()
    }
    
    // 배경 이미지 구독
    func backgroundImageRxSubscribe() {
        
        
        RxImageViewModel.shared.backgroundImageSubject
            .skip(until: RxImageViewModel.shared.backgroundImageTrigger)
            .debounce(.milliseconds(150), scheduler: MainScheduler.asyncInstance)
            .distinctUntilChanged()
            .subscribe { [weak self] (image) in
                print("backgroundImage Observable : 이미지가 변경되었습니다.")
                    self?.bgImageView.image = image
        } onError: { error in
            print("backgroundImage Subject Error : \(error.localizedDescription)")
        } onCompleted: {
            print("backgroundImage Subject Completed")
        } onDisposed: {
            print("backgroundImage Subject Disposed")
        }.disposed(by: disposeBag)
        
    }
    
}

extension MakeWallpaperViewController {

    /// `배경화면 편집` 버튼을 누르면 생성되는 Subview를 구성합니다.
    func makeBGEditView(view bgView: MainEditMenuView) {

        view.addSubview(bgView)
        bgView.isHidden = true

        bgView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomView.snp.top)
        }

    }


    func configureSubmenuBackground() {

        view.addSubview(trayRootView)
        trayRootView.snp.makeConstraints { make in
            make.bottom.equalTo(view)
            make.leading.trailing.equalTo(view)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-65)
        }

        let subviewHeight: CGFloat = 50
        view.addSubview(traySubView)
        traySubView.snp.makeConstraints { make in
            make.bottom.equalTo(trayRootView.snp.top)
            make.leading.trailing.equalTo(view)
            make.height.equalTo(subviewHeight)
        }

        view.addSubview(traySubViewInView)
        traySubViewInView.snp.makeConstraints { make in
            make.bottom.equalTo(traySubView.snp.top)
            make.leading.trailing.equalTo(view)
            make.height.equalTo(subviewHeight)
        }

    }

    //MARK: - ColorPicker 셋업
    func makeBGColorPicker() {

        view.addSubview(colorPickerView)
        colorPickerView.translatesAutoresizingMaskIntoConstraints = false
        colorPickerView.alpha = 0
        colorPickerView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(view)
            make.bottom.equalTo(bottomView.snp.top)
            make.height.equalTo(50)
        }

    }


}


extension MakeWallpaperViewController {
    //MARK: 사진 확대/축소 제스쳐

    /// 두손가락으로 핀치하는 제스쳐를 SuperView에 추가합니다.
    func addPinchGesture(selector: Selector) {
        var pinch = UIPinchGestureRecognizer()

        pinch = UIPinchGestureRecognizer(target: self, action: selector)
        self.view.addGestureRecognizer(pinch)
    }

    /// 두손가락으로 이미지를 확대, 축소 할수 있는 핀치액션을 구성합니다.
    @objc func pinchZoomAction(_ pinch: UIPinchGestureRecognizer) {
        mainImageView.transform = mainImageView.transform.scaledBy(x: pinch.scale, y: pinch.scale)
        pinch.scale = 1
    }

    //MARK: 더블 탭 제스쳐
    /// 화면을 두번 탭하면 이벤트가 발생하는 TapRecognizer를 구성합니다.
    /// - selector : 제스쳐의 action을 구성할 objc 메소드입니다.
    func addDoubleTapRecognizer(selector: Selector) {
        let doubleTap = UITapGestureRecognizer(target: self, action: selector)
        doubleTap.numberOfTapsRequired = 2
        self.view.addGestureRecognizer(doubleTap)
    }

    /// 더블 탭 액션 ( 기본배율에서 더블탭하면 배율 2배, 그외에는 1배로 초기화, )
    @objc func doubleTapZoomAction(_ recognizer: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.3) {
            if self.mainImageView.transform == CGAffineTransform(scaleX: 1, y: 1) {
                self.mainImageView.transform = CGAffineTransform(scaleX: 2, y: 2)

            } else {
                self.mainImageView.center = self.view.center
                self.mainImageView.transform = CGAffineTransform(scaleX: 1, y: 1)
            }
        }
    }


    /// PanGesture를 추가합니다.
    /// - selector : 제스쳐의 action을 구성할 objc 메소드입니다.
    func addPanGesture(selector: Selector) {
        let gesture = UIPanGestureRecognizer(target: self, action: selector)
        self.view.addGestureRecognizer(gesture)
    }

    /// 이미지를 드래그 할수 있는 제스쳐를 만듭니다.
    @objc func makeDragImageGesture(_ sender: UIPanGestureRecognizer) {


        // 지정된 보기의 좌표계에서 팬 제스처를 해석합니다.
        let translation = sender.translation(in: mainImageView)
        // print("Pan Gesture Translation(CGPoint) : \(translation)")

        ///.Began각 제스처 인식의 맨 처음에 한 번 호출됩니다.
        ///.Changed사용자가 "제스처" 과정에 있으므로 계속 호출됩니다.
        ///.Ended제스처의 끝에서 한 번 호출됩니다.
        switch sender.state {
        case .began:
            /// 처음 클릭하기 시작했을 때
            self.imageOriginalCenter = mainImageView.center // TrayView의 센터포인트를 저장합니다.

        case .changed:
            self.mainImageView.center = CGPoint(x: self.imageOriginalCenter.x + translation.x, y: self.imageOriginalCenter.y + translation.y)
        default:
            break
        }

    }

    /// PanGesture를 추가합니다.
    /// - selector : 제스쳐의 action을 구성할 objc 메소드입니다.
    func addEdgeGesture(selector: Selector) {
        let gesture = UIScreenEdgePanGestureRecognizer(target: self, action: selector)
        gesture.edges = .bottom
        self.view.addGestureRecognizer(gesture)
    }

}



extension MakeWallpaperViewController: RulerDelegate {

    func configureRulerViews() {


        edgeRulerView.rulerView.delegate = self
        view.addSubview(edgeRulerView)
        edgeRulerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomView.snp.top)
            make.height.equalTo(50)
        }

        view.addSubview(bgRulerView)
        bgRulerView.rulerView.delegate = self
        bgRulerView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(traySubView.snp.top)
            make.height.equalTo(50)
        }

    }


    /// Ruler의 값을 관찰하는 Delegate입니다
    func rulerValueChanged(_ ruler: RulerView, value: Float) {

        if ruler.hashValue == self.edgeRulerView.rulerView.hashValue {

            // 3~10
            if value > 3.0 {
                print("\(value)")
                let inset: CGFloat = CGFloat(value) * 10.0
                EditImageModel.shared.makeImageRoundBlur(imageView: self.mainImageView, insetY: inset)
            } else {
                EditImageModel.shared.makeImageRoundBlur(imageView: self.mainImageView, insetY: 0)
            }
        }

        if ruler.hashValue == self.bgRulerView.rulerView.hashValue {

            // // 3~10
            // if value > 3.0 {
            //     print("\(value)")
            //
                let radius: CGFloat = CGFloat(value) * 5 // value
                // Value를 받아서 리턴한다.
                let bluredImg = EditImageModel.shared.makeBlurImage(image: self.sourceImage, radius: radius)
                RxImageViewModel.shared.backgroundImageSubject.onNext(bluredImg)

                self.bgRulerViewValue = value
        }
    }
}


