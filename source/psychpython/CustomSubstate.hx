#if PYTHON_ALLOWED
package psychpython;

import flixel.FlxG;
import flixel.FlxObject;
import states.PlayState;
import backend.MusicBeatSubstate;

class CustomSubstate extends MusicBeatSubstate
{
	public static var name:String = 'unnamed';
	public static var instance:CustomSubstate; // [ФИКС ОШИБКИ]: Исправлен тип с CustomSub на CustomSubstate

	/**
	 * Инициализация методов субстейта для Python-интерпретатора.
	 * Аналог оригинального метода implement() для Lua.
	 */
	public static function implement(script:FunkinPython)
	{
		// Регистрируем методы управления окнами напрямую в Hython
		script.set("openCustomSubstate", openCustomSubstate);
		script.set("closeCustomSubstate", closeCustomSubstate);
		script.set("insertToCustomSubstate", insertToCustomSubstate);
	}

	public static function openCustomSubstate(name:String, ?pauseGame:Bool = false)
	{
		if (PlayState.instance == null) return;

		CustomSubstate.name = name;
		
		if (pauseGame)
		{
			FlxG.camera.followLerp = 0;
			PlayState.instance.persistentUpdate = false;
			PlayState.instance.persistentDraw = true;
			PlayState.instance.paused = true;
			if(FlxG.sound.music != null) {
				FlxG.sound.music.pause();
				PlayState.instance.vocals.pause();
			}
		}

		instance = new CustomSubstate(name);
		PlayState.instance.openSubState(instance);
		
		// Триггерим событие открытия субстейта во всех Python-скриптах
		PlayState.instance.callOnPythons("onCustomSubstateCreate", [name]);
	}

	public static function closeCustomSubstate()
	{
		if (instance != null)
		{
			PlayState.instance.closeSubState();
			return true;
			// Триггерим событие закрытия субстейта во всех Python-скриптах
			PlayState.instance.callOnPythons("onCustomSubstateDestroy", [name]);
		}
		return false;
	}

	public static function insertToCustomSubstate(tag:String, ?pos:Int = -1)
	{
		if(instance != null)
		{
			var tagObject:FlxObject = cast (MusicBeatState.getVariables().get(tag), FlxObject);

			if(tagObject != null)
			{
				if(pos < 0) instance.add(tagObject);
				else instance.insert(pos, tagObject);
				return true;
			}
		}
		return false;
	}

	// Перегружаем стандартные методы Flixel, чтобы прокидывать события внутрь Python
	override function create()
	{
		instance = this;
		PlayState.instance.setOnHScript('customSubstate', instance);
		PlayState.instance.setOnPythons('customSubstate', instance);
		PlayState.instance.setOnLuas('cunstomSubstate', instance);
		PlayState.instance.callOnScripts('onCustomSubstateCreate', [name]);
		super.create();
		PlayState.instance.callOnScripts('onCustomSubstateCreatePost', [name]);
		
	}
	public function new(name:String)
	{
		CustomSubstate.name = name;
		PlayState.instance.setOnHScript('customSubstateName', name);
		super();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}
	override function update(elapsed:Float)
	{
		PlayState.instance.callOnScripts('onCustomSubstateUpdate', [name, elapsed]);
		super.update(elapsed);
		PlayState.instance.callOnScripts('onCustomSubstateUpdatePost', [name, elapsed]);
	}
	override function destroy()
	{
		PlayState.instance.callOnScripts('onCustomSubstateDestroy', [name]);
		instance = null;
		name = 'unnamed';

		PlayState.instance.setOnHScript('customSubstate', null);
		PlayState.instance.setOnHScript('customSubstateName', name);
		super.destroy();
	}
}

#end
