using Core.Library1;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Console1
{
    class Program
    {
        static void Main(string[] args)
        {
            var c1 = new Class1();
            Console.WriteLine(c1.Foo("hello"));
        }
    }
}
