package com.qifun.qforce.importCsv;

import com.qifun.qforce.importCsv.Importer;
using haxe.locale.Translator;

class ImporterTest
{

	public static function main()
	{
    var baz:Baz = new Baz();

    Translator.translate('x${baz}x');
	}
}

@:nativeGen
class Base
{

  public function new()
  {
  }

  public function test()
  {

  }
}


@:nativeGen
@:bridgeProperties
// 必须可以访问自己的a(get, never)，还必须可以访问其他对象的a(get, never)，还必须可以访问基类的静态函数
class Baz extends BaseBaz
{

  @:protected
  public var _a:Null<Int>;

  public var a(get, never):Int;

  override function get_a():Int
  {
    if (_a == null)
    {
      _a = 1;
    }
    return _a;
  }
}

@:nativeGen
class ScalaBaz extends Base
{

  function a():Int return get_a();

  function get_a():Int return throw "Not implemented!";

}

@:nativeGen
@:native("com.qifun.qforce.importCsv.ScalaBaz")
extern class BaseBaz extends Base
{

  function get_a():Int;

}
