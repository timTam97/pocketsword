//
//  PSAboutScreenController.swift
//  PocketSword
//
//  Ported to Swift (Wave 2). The About screen: a WKWebView showing the
//  generated credits/CrossWire HTML, plus an "Email Us" feedback flow via
//  MFMailComposeViewController.
//
//  Behaviour preserved from PSAboutScreenController.{h,mm}, with ONE deliberate
//  change per the migration plan: the obsolete hardcoded device-name lookup
//  table (the ~80-line `platformString` map of "iPhone7,2" -> "iPhone 6" etc.,
//  long stale for any modern hardware) is DROPPED. The feedback email subject
//  now carries the raw hardware model identifier straight from uname(2)
//  (e.g. "iPhone17,1") instead of a friendly-but-wrong mapped name. This keeps
//  the diagnostic value of the field while removing the unmaintainable table.
//
//  The only Obj-C consumers (PSTabBarControllerDelegate.mm,
//  PSPreferencesController.mm) just alloc/init this VC, so the public surface
//  keeps the Obj-C class name PSAboutScreenController via @objc.
//
//  Originally created by Nic Carter on 12/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

import UIKit
import WebKit
import MessageUI

@objc(PSAboutScreenController)
final class PSAboutScreenController: UIViewController, WKNavigationDelegate, MFMailComposeViewControllerDelegate {

    @objc var aboutWebView: WKWebView?

    // MARK: - About HTML

    @objc class func generateAboutHTML() -> String {
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
        let build = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? ""

        var ofl = ""
        if let oflPath = Bundle.main.path(forResource: "OFL", ofType: "txt") {
            ofl = (try? String(contentsOfFile: oflPath, encoding: .utf8)) ?? ""
        }

        let body = """
        <div id="header">\n\
        			 <div class="title">PocketSword</div>\n\
        			 <div class="version"> Version \(version) (\(build))</div>\n\
        			 <center><i><a href="https://bitbucket.org/niccarter/pocketsword/overview">PocketSword on Bitbucket</a></i><br />\n\
        				<i><a href="http://www.crosswire.org/forums/mvnforum/listthreads?forum=16">User Forums</a></i><br />\n\
        				<i>@<a href="http://twitter.com/PocketSword">PocketSword</a> on Twitter</i></center>\n\
        		 </div>\n\
        		 <div id="main">\n\
        			<p><b>Developed by: </b><br />\n\
        				 Nic Carter; <br />\n\
        				 The CrossWire Bible Society\n\
        			</p>\n\
        			 <p><b>With help from: </b><br />\n\
        	  David Bell, \
        	  Manfred Bergmann, \
        	  Christoffer Björkskog, \
        	  Jan Bubík, \
        	  Vincenzo Carrubba, \
        	  Cheree Lynley Designs, \
        	  Dominique Corbex, \
        	  Bruno Gätjens González, \
        	  Grace Community Church (HK), \
        	  Yiguang Hu, \
        	  John Huss, \
        	  Nakamaru Kunio, \
        	  Laurence Rezkalla, \
        	  Timothy Shen, \
        	  Vitaliy, \
        	  Ian Wagner, \
        	  Henko van de Weerd \
        	  \n\
        	  <br />\n\
        	  &amp; all the PocketSword beta testers!\n\
        		  </p>\n\
        		</div>\n\
        			<p>If you would like to use these same Bible & Commentary modules on another platform, check out the following apps:<br />\n\
        					&bull; <i><a href="http://xiphos.org/">Xiphos (Windows, Linux/Unix)</a></i><br />\n\
        					&bull; <i><a href="http://mjdenham.github.io/and-bible/">AndBible (other mobile)</a></i><br />\n\
        					&bull; <i><a href="http://www.macsword.com/">Eloquent/MacSword</a></i><br />\n\
        					&bull; <i><a href="http://www.bibletime.info/">BibleTime (Linux/Unix and Windows)</a></i><br />\n\
        				</p>\n\
        			<p>If you would like to see PocketSword in your language and are willing to help translate it, please Email Us using the button in the top right corner &amp; we would love your help!</p>\
        	  \
        	  \n\
        	  \n\
        	  <p>PocketSword benefits from the following Open Source projects:<br />\n\
        	  &bull; <i><a href="http://www.crosswire.org/sword/index.jsp">The SWORD Project</a></i><br />\n\
        	  &bull; <i><a href="https://github.com/jdg/MBProgressHUD">MBProgressHUD</a></i><br />\n\
        	  </p>\
        	  <br />\n\
        	  <br />\n\
        	  <div class="crosswire">\n\
        	  <h2 class="headbar">CrossWire Bible Society</h2>\n\
        	  <p> &nbsp; &nbsp; &nbsp;The CrossWire Bible Society is an organization with the purpose to sponsor and provide a place for engineers and others to come and collaborate on free, open-source projects aimed at furthering the Kingdom of our God.  We are also a resource pool to other Bible societies and Christian organizations that can't afford-- or don't feel it's their place-- to maintain a quality programming staff in house.  We provide them with a number of tools that assist them with reaching their domain with Christ.  CrossWire is a non-income organization, which means that not only do we offer our services for free, but we also do not solicit donations to exist.  We exist because we, as a community come together and offer our services and time freely.</p>\n\
        \n\
        	  <p> &nbsp; &nbsp; &nbsp;The name was a pun of sorts, with the original idea that the Cross of Christ is our wire to God.  Over the years, the meaning has grown into one more appropriate to what a Bible society is.  The main purpose of a Bible Society is to distribute Scripture to as many people within a domain as possible.  Some examples are the American Bible Society, the German Bible Society, the Canadian Bible Society, the United Bible Societies-- under which most of the Bible societies of the world collaborate-- and many others.  You can view most of their stats of Scripture distribution to their region by visiting <a href="https://www.unitedbiblesocieties.org/distribution/">https://www.unitedbiblesocieties.org/distribution/</a>, then selecting a region and the Bible Society that serves that region.  Instead of having a geographic domain, CrossWire's domain is software users-- predominantly the global Internet-- or anyone we can reach across the wire.  Our Scripture distribution compares with the largest of the Bible Societies listed.</p>\n\
        \n\
        	  <p> &nbsp; &nbsp; &nbsp;Some examples of recent collaboration include traveling to Wycliffe Bible Translators to present and counsel on strategies to open source their software, participation with the American Bible Society to realize and promote the Bible Technologies Conference (<a href="http://www.bibletechnologies.org">http://www.bibletechnologies.org</a>), and subsequently, the OSIS initiative (of which the newsgroups and listservs for the working groups are hosted on our servers.<br /> </p>\n\
        	  </div>\n\
        	  <div class="crosswire">\n\
        	  <h2 class="headbar">Ezra SIL and Gentium Plus: </h2>\n\
        	  \(ofl)\n\
        	  </div>\n\
        	  <br />&nbsp;<br />
        """

        return """
        <?xml version="1.0" encoding="UTF-8"?>\n\
        		<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"\n\
        		"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">\n\
        		<html dir="ltr" xmlns="http://www.w3.org/1999/xhtml"\n\
        		xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"\n\
        		xsi:schemaLocation="http://www.w3.org/MarkUp/SCHEMA/xhtml11.xsd"\n\
        		xml:lang="en" >\n\
        		<meta name='viewport' content='width=device-width' />\n\
        		<meta name="color-scheme" content="light dark" />\n\
        		<head>\n\
        		<style type="text/css">\n\
        		:root { color-scheme: light dark; }\n\
        		html {\n\
        			-webkit-text-size-adjust: none; /* Never autoresize text */\n\
        		}\n\
        		body {\n\
        			color: CanvasText;\n\
        			background-color: Canvas;\n\
        			font-size: 11pt;\n\
        			font-family: \(AppConstants.defaultFontName);\n\
        			line-height: 130%;\n\
        		}\n\
        		#header {\n\
        			font-weight: bold;\n\
        			border-bottom: solid 1px gray;\n\
        			padding: 5px;\n\
        			background-color: #D5EEF9;\n\
        			color: black;\n\
        		}\n\
        		#main {\n\
        			padding: 10px;\n\
        			text-align: center;\n\
        		}\n\
        		div.version {\n\
        			font-size: 9pt;\n\
        			text-align: center;\n\
        		}\n\
        		div.title {\n\
        			font-size: 14pt;\n\
        			text-align: center;\n\
        		}\n\
        		i {\n\
        			font-size: 9pt;\n\
        			font-weight: lighter;\n\
        		}\n\
        		div.crosswire {\n\
        			font-size: 9pt;\n\
        		}\n\
        		h2.headbar {\n\
        			background-color : #660000;\n\
        			color : #dddddd;\n\
        			font-weight : bold;\n\
        			font-size:1em;\n\
        			padding-left:1em;\n\
        		}\n\
        		</style>\n\
        		</head>\n\
        		<body><div>\(body)</div></body></html>
        """
    }

    // MARK: - View lifecycle

    override func loadView() {
        let screenBounds = PSResizing.mainScreenBounds()
        let viewWidth = screenBounds.size.width
        let viewHeight = screenBounds.size.height

        let baseView = UIView(frame: CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight))

        let conf = WKWebViewConfiguration()
        conf.dataDetectorTypes = WKDataDetectorTypes.all.subtracting(.phoneNumber)

        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight), configuration: conf)
        wv.navigationDelegate = self
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wv.backgroundColor = UIColor.systemBackground
        wv.loadHTMLString("<html><body>&nbsp;</body></html>", baseURL: nil)
        baseView.addSubview(wv)
        self.aboutWebView = wv

        self.view = baseView
    }

    override func viewDidLoad() {
        self.navigationItem.title = NSLocalizedString("AboutTitle", comment: "About")

        let emailUsBarButtonItem = UIBarButtonItem(title: NSLocalizedString("EmailUsButton", comment: "Email Us"),
                                                   style: .plain,
                                                   target: self,
                                                   action: #selector(emailFeedback(_:)))
        self.navigationItem.rightBarButtonItem = emailUsBarButtonItem

        aboutWebView?.loadHTMLString(PSAboutScreenController.generateAboutHTML(), baseURL: nil)
        super.viewDidLoad()
    }

    // MARK: - Device model

    /// Raw hardware model identifier (e.g. "iPhone17,1", "iPad14,3", or "x86_64"
    /// / "arm64" on the Simulator) read straight from uname(2). Replaces the old
    /// stale hardcoded device-name lookup table.
    private var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine
    }

    // MARK: - Feedback email

    @objc func emailFeedback(_ sender: Any?) {
        let recipients = "pocketsword@icloud.com"

        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
        let device = UIDevice.current
        let subject = "PocketSword Feedback (v\(version) - \(device.systemName) \(device.systemVersion) (\(deviceModelIdentifier)))"

        if MFMailComposeViewController.canSendMail() {
            let mailComposeViewController = MFMailComposeViewController()
            mailComposeViewController.setSubject(subject)
            mailComposeViewController.setToRecipients([recipients])
            mailComposeViewController.mailComposeDelegate = self
            self.tabBarController?.present(mailComposeViewController, animated: true, completion: nil)
        }
    }

    func mailComposeController(_ controller: MFMailComposeViewController,
                              didFinishWith result: MFMailComposeResult,
                              error: Error?) {
        self.tabBarController?.dismiss(animated: true, completion: nil)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // MARK: - Memory management

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
