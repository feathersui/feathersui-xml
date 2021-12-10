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

	Usage:

	```hx
	@:build(com.feathersui.xml.FeathersUICoreNamespace.setup())
	class MyClass {}
	```

	@see `com.feathersui.xml.XmlComponent`
**/
class FeathersUICoreNamespace {
	public macro static function setup():Array<Field> {
		if (setupDone) {
			return null;
		}
		setupDone = true;
		XmlComponent.addNamespaceMapping(URI_FEATHERS_UI, MAPPINGS_FEATHERS_UI);
		return null;
	}

	#if macro
	private static var setupDone = false;
	private static final URI_FEATHERS_UI = "http://ns.feathersui.com/xml";

	private static final MAPPINGS_FEATHERS_UI = [
		// @formatter:off

		//components
		"Application" => "feathers.controls.Application",
		"AssetLoader" => "feathers.controls.AssetLoader",
		"Button" => "feathers.controls.Button",
		"Callout" => "feathers.controls.Callout",
		"Check" => "feathers.controls.Check",
		"ComboBox" => "feathers.controls.ComboBox",
		"GridView" => "feathers.controls.GridView",
		"GridViewColumn" => "feathers.controls.GridViewColumn",
		"Label" => "feathers.controls.Label",
		"LayoutGroup" => "feathers.controls.LayoutGroup",
		"ListView" => "feathers.controls.ListView",
		"Panel" => "feathers.controls.Panel",
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
		"TextArea" => "feathers.controls.TextArea",
		"TextCallout" => "feathers.controls.TextCallout",
		"TextInput" => "feathers.controls.TextInput",
		"ToggleButton" => "feathers.controls.ToggleButton",
		"ToggleSwitch" => "feathers.controls.ToggleSwitch",

		//collections
		"ArrayCollection" => "feathers.data.ArrayCollection",

		//layouts
		"AnchorLayout" => "feathers.layout.AnchorLayout",
		"AnchorLayoutData" => "feathers.layout.AnchorLayoutData",
		"HorizontalLayout" => "feathers.layout.HorizontalLayout",
		"HorizontalLayoutData" => "feathers.layout.HorizontalLayoutData",
		"VerticalLayout" => "feathers.layout.VerticalLayout",
		"VerticalLayoutData" => "feathers.layout.VerticalLayoutData"

		// @formatter:on
	];
	#end
}
