#if (PYTHON_ALLOWED && flxanimate)
package psychpython;

import openfl.utils.Assets;



using StringTools;

class FlxAnimateFunctions
{
	/**
	 * Инициализация методов работы с Adobe Animate атласами для Python-интерпретатора.
	 * Теперь использует оригинальный MusicBeatState.getVariables().
	 */
	public static function implement(script:FunkinPython)
	{
		var interp = script;

		// 1. Создание FlxAnimate-спрайта (makeFlxAnimateSprite)
		interp.set("makeFlxAnimateSprite", function(tag:String, ?x:Float = 0, ?y:Float = 0, ?loadFolder:String = null) {
			tag = tag.replace('.', '');
			
			// Берём старый спрайт напрямую из MusicBeatState
			var lastSprite = MusicBeatState.getVariables().get(tag);
			if(lastSprite != null)
			{
				lastSprite.kill();
				if(PlayState.instance != null) PlayState.instance.remove(lastSprite);
				lastSprite.destroy();
			}

			var mySprite:ModchartAnimateSprite = new ModchartAnimateSprite(x, y);
			if(loadFolder != null) Paths.loadAnimateAtlas(mySprite, loadFolder);
			
			// Сохраняем в общие переменные MusicBeatState
			MusicBeatState.getVariables().set(tag, mySprite);
			mySprite.active = true;
		});

		// 2. Динамическая загрузка атласа в существующий спрайт (loadAnimateAtlas)
		interp.set("loadAnimateAtlas", function(tag:String, folderOrImg:String, ?spriteJson:String = null, ?animationJson:String = null) {
			var spr:FlxAnimate = cast MusicBeatState.getVariables().get(tag);
			if(spr != null) Paths.loadAnimateAtlas(spr, folderOrImg, spriteJson, animationJson);
		});
		
		// 3. Добавление анимации по символу Flash (addAnimationBySymbol)
		interp.set("addAnimationBySymbol", function(tag:String, name:String, symbol:String, ?framerate:Float = 24, ?loop:Bool = false, ?matX:Float = 0, ?matY:Float = 0) {
			var obj:FlxAnimate = cast MusicBeatState.getVariables().get(tag);
			if(obj == null) return false;

			obj.anim.addBySymbol(name, symbol, framerate, loop, matX, matY);
			if(obj.anim.curSymbol == null)
			{
				var obj2:ModchartAnimateSprite = cast (obj, ModchartAnimateSprite);
				if(obj2 != null) obj2.playAnim(name, true);
				else obj.anim.play(name, true);
			}
			return true;
		});

		// 4. Добавление анимации со списком кадров (addAnimationBySymbolIndices)
		interp.set("addAnimationBySymbolIndices", function(tag:String, name:String, symbol:String, ?indices:Dynamic = null, ?framerate:Float = 24, ?loop:Bool = false, ?matX:Float = 0, ?matY:Float = 0) {
			var obj:FlxAnimate = cast MusicBeatState.getVariables().get(tag);
			if(obj == null) return false;

			var myIndices:Array<Int> = [];

			// ПАРСЕР ИНДЕКСОВ: Надежное приведение типов Python -> Haxe
			if(indices == null)
			{
				myIndices =[0];
			}
			else if(Std.isOfType(indices, String))
			{
				var strIndices:Array<String> = cast (indices, String).trim().split(',');
				for (i in 0...strIndices.length) {
					myIndices.push(Std.parseInt(strIndices[i]));
				}
			}
			else if(Std.isOfType(indices, Array))
			{
				myIndices = cast indices;
			}
			else 
			{
				myIndices =[0];
			}

			obj.anim.addBySymbolIndices(name, symbol, myIndices, framerate, loop, matX, matY);
			if(obj.anim.curSymbol == null)
			{
				var obj2:ModchartAnimateSprite = cast (obj, ModchartAnimateSprite);
				if(obj2 != null) obj2.playAnim(name, true);
				else obj.anim.play(name, true);
			}
			return true;
		});
	}
}
#end
