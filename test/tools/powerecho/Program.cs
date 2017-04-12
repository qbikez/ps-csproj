using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;

namespace powerecho
{
    class Program
    {
        static System.IO.TextWriter logOutput = null;
        static int? exitCode = null;
        static List<string> result = new List<string>();
        static bool returnArgs = true;
        static int Main(string[] args)
        {
            args = ParseLogArgs(args);
            args = ParseArgs(args);
            EchoArgs(args);
            WriteResultToOutput();
            return exitCode ?? 0;
        }

        private static void WriteResultToOutput()
        {
            foreach (var r in result)
            {
                System.Console.Out.WriteLine(r);
            }
        }

        private static string GetArgValue(string[] args, ref int argPos)
        {
            var valPos = argPos + 1;
            if (args.Length < valPos) { throw new ArgumentException($"parameter '{args[argPos]}' requires a value"); };
            if (args[valPos].StartsWith("-")) { throw new ArgumentException($"parameter '{args[argPos]}' requires a value"); };

            argPos = valPos;
            return args[valPos];
        }

        private static string[] ParseLogArgs(string[] args)
        {
            List<string> result = new List<string>();
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "--log")
                {
                    var val = GetArgValue(args, ref i);
                    if (val == "stderr")
                    {
                        logOutput = System.Console.Error;
                        Log("using stderr for log output");
                    }
                    else if (val == "stdout")
                    {
                        logOutput = System.Console.Out;
                        Log("using stdout for log output");
                    }
                      else if (val == "null")
                    {
                        logOutput = null;
                        Log("log disabled");
                    }
                    else
                    {
                        throw new NotSupportedException($"parameter '{args[i]}' value should be one of: [stderr, stdout, null]");
                    }
                } else {
                    result.Add(args[i]);
                }
            }
            return result.ToArray();
        }
        private static string[] ParseArgs(string[] args)
        {
            List<string> result = new List<string>();
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "--exitCode")
                {
                    var val = GetArgValue(args, ref i);
                    exitCode = int.Parse(val);
                    Log($"setting exticode to {val}");
                }
                else if (args[i] == "--return")
                {
                    var val = GetArgValue(args, ref i);
                    if (val == "{args}") {
                        returnArgs = true;
                        Log($"will return 'args list to output'");
                    } else {
                        result.Add(val);
                        Log($"will return '{val}'");
                    }
                }
                else {
                    result.Add(args[i]);
                }
            }

            return result.ToArray();
        }

        private static void Log(string msg, string level = "verbose") {
            logOutput?.WriteLine($"{level}: {msg}");
        }

        static void EchoArgs(string[] args)
        {
            Log("Power echo here! Args:");
            for (int i = 0; i < args.Length; i++)
            {
                var msg = $"Arg {i} is <{args[i]}>";
                Log(msg);
                if (returnArgs) Console.Out.WriteLine(msg);
            }
            if (returnArgs) {
                // mimic echoargs behavior
                Console.Out.WriteLine("Command line:");
                // dotnet runs as 
                var originalArgs =  Environment.GetCommandLineArgs();
                var exe = Environment.GetCommandLineArgs()[0].Replace(".dll",".exe");
                for(int i = 0; i < originalArgs.Length; i++) {
                    if (originalArgs[i].Contains(" ")) originalArgs[i] = $"\"{originalArgs[i]}\"";
                }
                System.Console.Write($"\"{exe}\" ");
                System.Console.WriteLine(string.Join(" ", originalArgs, 1, originalArgs.Length - 1));
            }
        }
    }
}
