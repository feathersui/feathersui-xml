package com.feathersui.xml;

import utest.Assert;
import utest.Test;

class TestXmlComponentDeclarationsCoreTypes extends Test {
	public function new() {
		super();
	}

	public function testFloat():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Float id="float">123.4</hx:Float>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals(123.4, instance.float);
	}

	public function testInt():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Int id="int">-123</hx:Int>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals(-123, instance.int);
	}

	public function testUInt():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:UInt id="uint">123</hx:UInt>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals(123, instance.uint);
	}

	public function testBoolFalse():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Bool id="bool">false</hx:Bool>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.isFalse(instance.bool);
	}

	public function testBoolTrue():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Bool id="bool">true</hx:Bool>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.isTrue(instance.bool);
	}

	public function testString():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:String id="string">Hello XML</hx:String>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals("Hello XML", instance.string);
	}

	public function testArrayEmpty():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Array id="array"></hx:Array>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals(0, instance.array.length);
	}

	public function testArrayWithItems():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Array id="array">
						<hx:String>a</hx:String>
						<hx:String>b</hx:String>
						<hx:String>c</hx:String>
					</hx:Array>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals(3, instance.array.length);
		Assert.equals("a", instance.array[0]);
		Assert.equals("b", instance.array[1]);
		Assert.equals("c", instance.array[2]);
	}

	public function testDynamicNoFields():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Dynamic id="dyn"></hx:Dynamic>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals(0, Reflect.fields(instance.dyn).length);
	}

	public function testDynamicAttributeProperty():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Dynamic id="dyn" value="123.4"></hx:Dynamic>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals(123.4, instance.dyn.value);
	}

	public function testDynamicElementProperty():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Dynamic id="dyn">
						<hx:value>123.4</hx:value>
					</hx:Dynamic>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals(123.4, instance.dyn.value);
	}

	public function testDynamicAttributeAndElementProperties():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Dynamic id="dyn" value1="123.4">
						<hx:value2>456.7</hx:value2>
					</hx:Dynamic>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals(123.4, Reflect.field(instance.dyn, "value1"));
		Assert.equals(456.7, Reflect.field(instance.dyn, "value2"));
	}

	public function testAnyNoFields():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Any id="any"></hx:Any>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals(0, Reflect.fields(instance.any).length);
	}

	public function testAnyAttributeProperty():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Any id="any" value="123.4"></hx:Any>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals(123.4, Reflect.field(instance.any, "value"));
	}

	public function testAnyElementProperty():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Any id="any">
						<hx:value>123.4</hx:value>
					</hx:Any>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals(123.4, Reflect.field(instance.any, "value"));
	}

	public function testAnyAttributeAndElementProperties():Void {
		var instance = XmlComponent.withMarkup(
			// @formatter:off
			'<hx:Dynamic xmlns:hx="http://ns.haxe.org/4/xml">
				<hx:Declarations>
					<hx:Any id="any" value1="123.4">
						<hx:value2>456.7</hx:value2>
					</hx:Any>
				</hx:Declarations>
			</hx:Dynamic>');
			// @formatter:on
		Assert.equals(123.4, Reflect.field(instance.any, "value1"));
		Assert.equals(456.7, Reflect.field(instance.any, "value2"));
	}
}
