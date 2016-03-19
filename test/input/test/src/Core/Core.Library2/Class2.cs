using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Core.LibraryProject2
{
    public class Class2
    {
        public string Bar(string msg)
        {
            Core.CoreClass.Initialize();
            return $"foobar {msg}";
        }
    }
}
