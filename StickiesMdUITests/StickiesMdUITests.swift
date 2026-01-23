//
//  StickiesMdUITests.swift
//  StickiesMdUITests
//
//  Created by Gemini on 2026/01/23.
//

import XCTest

final class StickiesMdUITests: XCTestCase {

    override func setUpWithError() throws {
        // UIテストでは、失敗が発生した時点でテストを停止するのが一般的です
        continueAfterFailure = false
    }

    func testLaunch() throws {
        // UIアプリケーションのインスタンスを作成
        let app = XCUIApplication()
        // アプリ起動
        app.launch()
        
        // 起動確認：少なくとも1つのウィンドウが開いていること
        XCTAssertTrue(app.windows.firstMatch.exists, "アプリ起動後にウィンドウが表示されるべきです")
        
        // 追加の検証: スクリーンショットを撮るなど（必要に応じて）
        // let attachment = XCTAttachment(screenshot: app.screenshot())
        // attachment.lifetime = .keepAlways
        // add(attachment)
    }
}
