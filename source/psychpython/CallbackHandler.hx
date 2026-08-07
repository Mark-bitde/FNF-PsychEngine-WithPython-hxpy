#if PYTHON_ALLOWED
package psychpython;

import hxpy.Py;
import hxpy.PyImport;
import hxpy.PyModule;
import hxpy.PyDict;
import hxpy.PyCallable;
import hxpy.PyObject;
import hxpy.PyTuple;
import hxpy.PyLong;
import hxpy.PyFloat;
import hxpy.PyUnicode;
import cpp.RawPointer;
import haxe.Exception;

class CallbackHandler
{
    /**
     * Inline-метод вызова Python-функций через нативный C C-API (hxpy).
     * @param p Экземпляр твоего класса FunkinPython.
     * @param fname Имя функции (например, 'onCreate' или 'onUpdate').
     * @param args Необязательный массив аргументов для передачи в Python.
     * @return Int (1 — функция успешно найдена и вызвана, 0 — функции нет в скрипте).
     */
    public static inline function call(p:FunkinPython, fname:String, ?args:Array<Dynamic>):Int
    {
        try 
        {
            // 1. Получаем глобальный словарь модуля __main__
            var mainModule:RawPointer<hxpy.PyObject> = untyped __cpp__("PyImport_AddModule(\"__main__\")");
            var mainDict:RawPointer<hxpy.PyObject> = PyModule.getDict(mainModule);
            
            // 2. Извлекаем объект функции из Python по имени
            var funcObj:RawPointer<hxpy.PyObject> = untyped __cpp__("PyDict_GetItemString({0}, {1}.__s)", mainDict, fname);
            
            // Если метода 'def' с таким именем в скрипте нет — возвращаем 0 (как у тебя в логике)
            if (funcObj == null || !PyCallable.check(funcObj)) return 0;

            if (args == null) args = [];

            // 3. Создаем кортеж PyTuple под аргументы
            var pyArgs:RawPointer<hxpy.PyObject> = PyTuple.newPyTuple(args.length);
            
            for (i in 0...args.length) {
                var val:Dynamic = args[i];
                var pyVal:RawPointer<hxpy.PyObject> = null;
                
                if (Std.isOfType(val, Int)) pyVal = PyLong.fromLong(cast val);
                else if (Std.isOfType(val, Float)) pyVal = PyFloat.fromDouble(cast val);
                else if (Std.isOfType(val, String)) {
                    var strVal:String = cast val;
                    pyVal = untyped __cpp__("PyUnicode_FromString({0}.__s)", strVal);
                }
                else if (Std.isOfType(val, Bool)) pyVal = val ? Py.TRUE : Py.FALSE;
                else if (val == null) pyVal = Py.NONE;
                
                if (pyVal != null) {
                    PyTuple.setItem(pyArgs, i, pyVal);
                }
            }

            // 4. Нативно вызываем метод Python
            PyObject.callObject(funcObj, pyArgs);

            return 1; // Успешно выполнено
        }
        catch(e:Exception)
        {
            // Ловим рантайм-ошибки самого скрипта
            trace('PYTHON RUNTIME ERROR IN $fname: ' + e.message);
            return 0;
        }
    }
}
#end
