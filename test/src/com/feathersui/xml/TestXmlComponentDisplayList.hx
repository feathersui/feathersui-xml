package com.feathersui.xml;

import feathers.layout.VerticalLayout;
import feathers.controls.TextInput;
import feathers.controls.Button;
import feathers.controls.LayoutGroup;
import utest.Assert;
import utest.Test;

class TestXmlComponentDisplayList extends Test {
	public function new() {
		super();
	}

	public function testContainerEmpty():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<f:LayoutGroup xmlns:f="http://ns.feathersui.com/xml">
			</f:LayoutGroup>');
			// @formatter:on
		Assert.isTrue(Std.isOfType(instance, LayoutGroup));
		Assert.equals(0, instance.numChildren);
	}

	public function testContainerWithChild():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<f:LayoutGroup xmlns:f="http://ns.feathersui.com/xml">
				<f:Button id="btn" text="Click Me">
					<f:variant>my_custom_button</f:variant>
				</f:Button>
			</f:LayoutGroup>');
			// @formatter:on
		Assert.isTrue(Std.isOfType(instance, LayoutGroup));
		Assert.equals(1, instance.numChildren);

		Assert.isTrue(Std.isOfType(instance.btn, Button));
		var btn:Button = instance.btn;
		Assert.equals(instance, btn.parent);
		Assert.equals(0, instance.getChildIndex(btn));
		Assert.equals("Click Me", btn.text);
		Assert.equals("my_custom_button", btn.variant);
	}

	public function testContainerWithChildren():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<f:LayoutGroup xmlns:f="http://ns.feathersui.com/xml">
				<f:TextInput id="txt"/>
				<f:Button id="btn"/>
			</f:LayoutGroup>');
			// @formatter:on
		Assert.isTrue(Std.isOfType(instance, LayoutGroup));
		Assert.equals(2, instance.numChildren);

		Assert.isTrue(Std.isOfType(instance.txt, TextInput));
		var txt:TextInput = instance.txt;
		Assert.equals(instance, txt.parent);
		Assert.equals(0, instance.getChildIndex(txt));

		Assert.isTrue(Std.isOfType(instance.btn, Button));
		var btn:Button = instance.btn;
		Assert.equals(instance, btn.parent);
		Assert.equals(1, instance.getChildIndex(btn));
	}

	public function testContainerWithElementProperty():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<f:LayoutGroup xmlns:f="http://ns.feathersui.com/xml">
				<f:layout>
					<f:VerticalLayout gap="123.4">
						<f:paddingTop>456.7</f:paddingTop>
					</f:VerticalLayout>
				</f:layout>
			</f:LayoutGroup>');
			// @formatter:on
		Assert.isTrue(Std.isOfType(instance, LayoutGroup));
		Assert.equals(0, instance.numChildren);

		Assert.isTrue(Std.isOfType(instance.layout, VerticalLayout));
		var layout:VerticalLayout = cast(instance.layout, VerticalLayout);
		Assert.equals(123.4, layout.gap);
		Assert.equals(456.7, layout.paddingTop);
	}
}
