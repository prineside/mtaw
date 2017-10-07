using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

// Can be compiled by running "csc privatecmdrun.cs"
// csc.exe can be found at: C:\Program Files (x86)\MSBuild\12.0\Bin

namespace Protocol
{
    class Program
    {
		static string protocolName = "privatecmdrun";
		
        static void Main(string[] args)
        {
            if (args.Length > 0) cmdRun(DecodeFrom64(args[0]));
        }
        static string DecodeFrom64(string txt)
        {
           try
           {
               txt = txt.Substring(protocolName.Length + 3, txt.Length - ( protocolName.Length + 4 )); // With ://
               byte[] bytes = System.Convert.FromBase64String(txt);
               return System.Text.Encoding.ASCII.GetString(bytes);
           }
           catch (Exception e)
           {
               return e.Message;
           }
        }
        static void cmdRun(string cmdLine)
        {
            if (cmdLine == "") return;
            System.Diagnostics.Process process = new System.Diagnostics.Process();
            System.Diagnostics.ProcessStartInfo startInfo = new System.Diagnostics.ProcessStartInfo();
            startInfo.WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden;
            startInfo.FileName = @"C:\windows\system32\cmd.exe";
            startInfo.Arguments = @" /C """ + cmdLine + @"""";
            startInfo.CreateNoWindow = true;
            process.StartInfo = startInfo;
            process.Start();
        }
    }
}
//http://support.microsoft.com/kb/830473
//On computers running Microsoft Windows XP or later, the maximum length of the string that you can use 
//at the command prompt is 8191 characters. On computers running Microsoft Windows 2000 or Windows NT 4.0, 
//the maximum length of the string that you can use at the command prompt is 2047 characters.
