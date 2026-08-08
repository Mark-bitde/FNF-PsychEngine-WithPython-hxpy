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
    
    public static inline function call(p:FunkinPython, fname:String, ?args:Array<Dynamic>):Int
    {
        try 
        {
            var mainModule:RawPointer<hxpy.PyObject> = untyped __cpp__("PyImport_AddModule(\"__main__\")");
            var mainDict:RawPointer<hxpy.PyObject> = PyModule.getDict(mainModule);
            
            var funcObj:RawPointer<hxpy.PyObject> = untyped __cpp__("PyDict_GetItemString({0}, {1}.__s)", mainDict, fname);
            
            if (funcObj == null || !PyCallable.check(funcObj)) return 0;

            if (args == null) args = [];

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

            PyObject.callObject(funcObj, pyArgs);

            return 1; 
        }
        catch(e:Exception)
        {
            trace('PYTHON RUNTIME ERROR IN $fname: ' + e.message);
            return 0;
        }
    }
}
#end
