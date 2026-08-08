#if PYTHON_ALLOWED
package psychpython;

import flixel.FlxG;
import flixel.util.FlxSave;
import flixel.util.FlxColor;
import states.PlayState;
import backend.CoolUtil;
import backend.Paths;
import backend.MusicBeatState;
import openfl.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class ExtraFunctions
{
	public static function implement(script:FunkinPython)
	{
		var interp = script;

		
		interp.set("keyboardJustPressed", function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		interp.set("keyboardPressed", function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		interp.set("keyboardReleased", function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		interp.set("anyGamepadJustPressed", function(name:String) return FlxG.gamepads.anyJustPressed(name));
		interp.set("anyGamepadPressed", function(name:String) return FlxG.gamepads.anyPressed(name));
		interp.set("anyGamepadReleased", function(name:String) return FlxG.gamepads.anyJustReleased(name));

		interp.set("gamepadAnalogX", function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;
			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		interp.set("gamepadAnalogY", function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;
			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		interp.set("gamepadJustPressed", function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;
			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		interp.set("gamepadPressed", function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;
			return Reflect.getProperty(controller.pressed, name) == true;
		});
		interp.set("gamepadReleased", function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;
			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		interp.set("keyJustPressed", function(name:String = '') {
			name = StringTools.trim(name.toLowerCase());
			switch(name) {
				case 'left': return PlayState.instance.controls.NOTE_LEFT_P;
				case 'down': return PlayState.instance.controls.NOTE_DOWN_P;
				case 'up': return PlayState.instance.controls.NOTE_UP_P;
				case 'right': return PlayState.instance.controls.NOTE_RIGHT_P;
				default: return PlayState.instance.controls.justPressed(name);
			}
		});
		interp.set("keyPressed", function(name:String = '') {
			name = StringTools.trim(name.toLowerCase());
			switch(name) {
				case 'left': return PlayState.instance.controls.NOTE_LEFT;
				case 'down': return PlayState.instance.controls.NOTE_DOWN;
				case 'up': return PlayState.instance.controls.NOTE_UP;
				case 'right': return PlayState.instance.controls.NOTE_RIGHT;
				default: return PlayState.instance.controls.pressed(name);
			}
		});
		interp.set("keyReleased", function(name:String = '') {
			name = StringTools.trim(name.toLowerCase());
			switch(name) {
				case 'left': return PlayState.instance.controls.NOTE_LEFT_R;
				case 'down': return PlayState.instance.controls.NOTE_DOWN_R;
				case 'up': return PlayState.instance.controls.NOTE_UP_R;
				case 'right': return PlayState.instance.controls.NOTE_RIGHT_R;
				default: return PlayState.instance.controls.justReleased(name);
			}
		});

		
		interp.set("initSaveData", function(name:String, ?folder:String = 'psychenginemods') {
			var variables = MusicBeatState.getVariables();
			if(!variables.exists('save_$name')) {
				var save:FlxSave = new FlxSave();
				save.bind(name, CoolUtil.getSavePath() + '/' + folder);
				variables.set('save_$name', save);
				return;
			}
			trace('initSaveData: Save file already initialized: ' + name);
		});
		interp.set("flushSaveData", function(name:String) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				variables.get('save_$name').flush();
				return;
			}
			trace('flushSaveData: Save file not initialized: ' + name);
		});
		interp.set("getDataFromSave", function(name:String, field:String, ?defaultValue:Dynamic = null) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				var saveData = variables.get('save_$name').data;
				if(Reflect.hasField(saveData, field))
					return Reflect.field(saveData, field);
				else
					return defaultValue;
			}
			return defaultValue;
		});
		interp.set("setDataFromSave", function(name:String, field:String, value:Dynamic) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				Reflect.setField(variables.get('save_$name').data, field, value);
				return;
			}
		});
		interp.set("eraseSaveData", function(name:String) {
			var variables = MusicBeatState.getVariables();
			if (variables.exists('save_$name')) {
				variables.get('save_$name').erase();
				return;
			}
		});

		
		interp.set("checkFileExists", function(filename:String, ?absolute:Bool = false) {
			#if MODS_ALLOWED
			if(absolute) return FileSystem.exists(filename);
			return FileSystem.exists(Paths.getPath(filename, TEXT));
			#else
			if(absolute) return Assets.exists(filename, TEXT);
			return Assets.exists(Paths.getPath(filename, TEXT));
			#end
		});
		interp.set("saveFile", function(path:String, content:String, ?absolute:Bool = false) {
			try {
				#if MODS_ALLOWED
				if(!absolute)
					File.saveContent(Paths.mods(path), content);
				else
				#end
					File.saveContent(path, content);
				return true;
			} catch (e:Dynamic) {
				trace("saveFile: Error trying to save " + path + ": " + e);
			}
			return false;
		});
		interp.set("deleteFile", function(path:String, ?ignoreModFolders:Bool = false, ?absolute:Bool = false) {
			try {
				var lePath:String = path;
				if(!absolute) lePath = Paths.getPath(path, TEXT, !ignoreModFolders);
				if(FileSystem.exists(lePath)) {
					FileSystem.deleteFile(lePath);
					return true;
				}
			} catch (e:Dynamic) {
				trace("deleteFile: Error trying to delete " + path + ": " + e);
			}
			return false;
		});
		interp.set("getTextFromFile", function(path:String, ?ignoreModFolders:Bool = false) {
			return Paths.getTextFromFile(path, ignoreModFolders);
		});
		interp.set("directoryFileList", function(folder:String) {
			var list:Array<String> = [];
			#if sys
			if(FileSystem.exists(folder)) {
				for (file in FileSystem.readDirectory(folder)) {
					if (!list.contains(file)) {
						list.push(file);
					}
				}
			}
			#end
			return list;
		});
	}
}
#end
