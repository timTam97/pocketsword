/*
	PocketSword - A frontend for viewing SWORD project modules on the iPhone and iPod Touch
	Copyright (C) 2008-2010 CrossWire Bible Society

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program; if not, write to the Free Software Foundation, Inc.,
	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

// PSLaunchViewController + the PSLaunchDelegate protocol were migrated to Swift
// in Wave 4 (PSLaunchViewController.swift) — the former PSLaunchViewController.h is
// deleted. The @objc(PSLaunchDelegate) protocol lives in the generated
// PocketSword-Swift.h, which may NOT be imported from a public Obj-C header (§2A
// Rule 2). A forward @protocol decl cannot satisfy `<PSLaunchDelegate>` in this
// @interface line either, so the conformance is declared in a class extension in
// the .mm (which CAN import PocketSword-Swift.h). PocketSwordSceneDelegate itself
// is the NEXT file migrated; until then it stays Obj-C and binds the Swift
// protocol via the .mm.
@interface PocketSwordSceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (nonatomic, strong) UIWindow *window;

@end
