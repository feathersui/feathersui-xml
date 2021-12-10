/*
	XML Components for Feathers UI
	Copyright 2021 Bowler Hat LLC. All Rights Reserved.

	This program is free software. You can redistribute and/or modify it in
	accordance with the terms of the accompanying license agreement.
 */

package com.feathersui.xml;

import haxe.macro.Expr.Field;

/**
	Registers namespace mappings for the core Feathers UI library with the
	`XmlComponent` class. The namespace URI for Feathers UI is
	`http://ns.feathersui.com/xml`.

	To initialize this namespace, call the `setup()` function in your
	_project.xml_ file or as a build macro.

	```xml
	<!-- project.xml -->
	<haxeflag name="--macro" value="com.feathersui.xml.FeathersUICoreNamespace.setup()"/>
	```

	```haxe
	// build macro
	@:build(com.feathersui.xml.FeathersUICoreNamespace.setup())
	class MyClass extends Application {}
	```

	Then, add `xmlns:f="http://ns.feathersui.com/xml"` to the root element of
	your XML component.

	@see `com.feathersui.xml.XmlComponent`
**/
class FeathersUICoreNamespace {
	#if macro
	public macro static function setup():Array<Field> {
		if (setupDone) {
			return null;
		}
		setupDone = true;
		XmlComponent.addNamespaceMapping(URI_FEATHERS_UI, MAPPINGS_FEATHERS_UI);
		return null;
	}

	private static var setupDone = false;
	private static final URI_FEATHERS_UI = "http://ns.feathersui.com/xml";

	private static final MAPPINGS_FEATHERS_UI = [
		// @formatter:off

		// components
		"Application" => "feathers.controls.Application",
		"AssetLoader" => "feathers.controls.AssetLoader",
		"Button" => "feathers.controls.Button",
		"ButtonBar" => "feathers.controls.ButtonBar",
		"Callout" => "feathers.controls.Callout",
		"Check" => "feathers.controls.Check",
		"ComboBox" => "feathers.controls.ComboBox",
		"DatePicker" => "feathers.controls.DatePicker",
		"HDividedBox" => "feathers.controls.HDividedBox",
		"VDividedBox" => "feathers.controls.VDividedBox",
		"Drawer" => "feathers.controls.Drawer",
		"Form" => "feathers.controls.Form",
		"FormItem" => "feathers.controls.FormItem",
		"GridView" => "feathers.controls.GridView",
		"GridViewColumn" => "feathers.controls.GridViewColumn",
		"GroupListView" => "feathers.controls.GroupListView",
		"Header" => "feathers.controls.Header",
		"ItemRenderer" => "feathers.controls.ItemRenderer",
		"Label" => "feathers.controls.Label",
		"LayoutGroup" => "feathers.controls.LayoutGroup",
		"LayoutGroupItemRenderer" => "feathers.controls.LayoutGroupItemRenderer",
		"ListView" => "feathers.controls.ListView",
		"NumericStepper" => "feathers.controls.NumericStepper",
		"PageIndicator" => "feathers.controls.PageIndicator",
		"Panel" => "feathers.controls.Panel",
		"PopUpDatePicker" => "feathers.controls.PopUpDatePicker",
		"PopUpListView" => "feathers.controls.PopUpListView",
		"HProgressBar" => "feathers.controls.HProgressBar",
		"VProgressBar" => "feathers.controls.VProgressBar",
		"Radio" => "feathers.controls.Radio",
		"RouterNavigator" => "feathers.controls.RouterNavigator",
		"HScrollBar" => "feathers.controls.HScrollBar",
		"VScrollBar" => "feathers.controls.VScrollBar",
		"ScrollContainer" => "feathers.controls.ScrollContainer",
		"HSlider" => "feathers.controls.HSlider",
		"VSlider" => "feathers.controls.VSlider",
		"StackNavigator" => "feathers.controls.StackNavigator",
		"TabBar" => "feathers.controls.TabBar",
		"TabNavigator" => "feathers.controls.TabNavigator",
		"TextArea" => "feathers.controls.TextArea",
		"TextCallout" => "feathers.controls.TextCallout",
		"TextInput" => "feathers.controls.TextInput",
		"ToggleButton" => "feathers.controls.ToggleButton",
		"ToggleSwitch" => "feathers.controls.ToggleSwitch",
		"TreeView" => "feathers.controls.TreeView",

		// collections
		"ArrayCollection" => "feathers.data.ArrayCollection",
		"ArrayHierarchicalCollection" => "feathers.data.ArrayHierarchicalCollection",
		"TreeCollection" => "feathers.data.TreeCollection",
		"TreeNode" => "feathers.data.TreeNode",

		// layouts
		"AnchorLayout" => "feathers.layout.AnchorLayout",
		"AnchorLayoutData" => "feathers.layout.AnchorLayoutData",
		"HorizontalLayout" => "feathers.layout.HorizontalLayout",
		"HorizontalLayoutData" => "feathers.layout.HorizontalLayoutData",
		"HorizontalListLayout" => "feathers.layout.HorizontalListLayout",
		"ResponsiveGridLayout" => "feathers.layout.ResponsiveGridLayout",
		"ResponsiveGridLayoutData" => "feathers.layout.ResponsiveGridLayoutData",
		"TiledRowsLayout" => "feathers.layout.TiledRowsLayout",
		"TiledRowsListLayout" => "feathers.layout.TiledRowsListLayout",
		"PagedTiledRowsListLayout" => "feathers.layout.PagedTiledRowsListLayout",
		"VerticalLayout" => "feathers.layout.VerticalLayout",
		"VerticalLayoutData" => "feathers.layout.VerticalLayoutData",
		"VerticalListLayout" => "feathers.layout.VerticalListLayout",
		"VerticalListFixedRowLayout" => "feathers.layout.VerticalListFixedRowLayout",

		// skins
		"CircleSkin" => "feathers.skins.CircleSkin",
		"EllipseSkin" => "feathers.skins.EllipseSkin",
		"HorizontalLineSkin" => "feathers.skins.HorizontalLineSkin",
		"LeftAndRightBorderSkin" => "feathers.skins.LeftAndRightBorderSkin",
		"PillSkin" => "feathers.skins.PillSkin",
		"RectangleSkin" => "feathers.skins.RectangleSkin",
		"TabSkin" => "feathers.skins.TabSkin",
		"TopAndBottomBorderSkin" => "feathers.skins.TopAndBottomBorderSkin",
		"TriangleSkin" => "feathers.skins.TriangleSkin",
		"UnderlineSkin" => "feathers.skins.UnderlineSkin",
		"VerticalLineSkin" => "feathers.skins.VerticalLineSkin",

		// @formatter:on
	];
	#end
}
