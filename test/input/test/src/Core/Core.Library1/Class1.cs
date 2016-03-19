using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Core.LibraryNuget1
{
    public class Class1
    {
        public string Foo(string msg)
        {
            Core.CoreClass.Initialize();
            return $"bar {msg}";
        }
    }
}
