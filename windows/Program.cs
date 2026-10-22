using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

internal static class Program {
 [STAThread] static void Main() {
  using var singleton = new Mutex(true, "Local\\PocketPlay", out bool first);
  if (!first) return;
  ApplicationConfiguration.Initialize(); Application.Run(new Tray());
 }
}
sealed class Tray : ApplicationContext {
 readonly string root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PocketPlay");
 readonly string avdHome = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".android", "avd");
 readonly NotifyIcon icon; readonly ToolStripMenuItem status;
 readonly System.Windows.Forms.Timer timer = new() { Interval = 700 };
 Process? emulator; bool busy, quitting; IntPtr window;
 string Sdk => Path.Combine(root, "sdk");
 string Config => Path.Combine(avdHome, "PocketPlay_API35.avd", "config.ini");
 public Tray() {
  Directory.CreateDirectory(root);
  var menu = new ContextMenuStrip(); status = new ToolStripMenuItem("Pocket Play · Android") { Enabled = false }; menu.Items.Add(status);
  menu.Items.Add("启动 / 安装 Android", null, async (_,_) => await Guard(Start));
  menu.Items.Add("显示窗口", null, (_,_) => Show());
  menu.Items.Add("隐藏到托盘", null, (_,_) => Hide());
  menu.Items.Add("关闭模拟器（保存快照）", null, async (_,_) => await Guard(Stop));
  var sizes = new ToolStripMenuItem("显示比例");
  foreach (var item in new[] { ("手机",1080,2400,420), ("平板",2560,1600,320), ("宽屏",1920,1080,240), ("恢复默认",1080,2400,420) }) {
   var p = item;
   sizes.DropDownItems.Add(p.Item1, null, async (_,_) => await Guard(async () => {
    if (!File.Exists(Config)) { await Start(); return; }
    bool running = emulator is { HasExited:false }; await Stop();
    var lines = File.ReadAllLines(Config).Where(l => !l.StartsWith("hw.lcd.width=") && !l.StartsWith("hw.lcd.height=") && !l.StartsWith("hw.lcd.density=")).ToList();
    lines.AddRange(new[] {$"hw.lcd.width={p.Item2}",$"hw.lcd.height={p.Item3}",$"hw.lcd.density={p.Item4}"});
    File.WriteAllLines(Config,lines,new UTF8Encoding(false)); if (running) await Start();
   }));
  }
  menu.Items.Add(sizes);
  menu.Items.Add("打开日志", null, (_,_) => { if (File.Exists(Path.Combine(root,"emulator.log"))) Process.Start(new ProcessStartInfo("notepad.exe", $"\"{Path.Combine(root,"emulator.log")}\"") { UseShellExecute=true }); });
  menu.Items.Add("彻底退出", null, async (_,_) => await Guard(async () => { await Stop(); quitting=true; icon!.Visible=false; Application.ExitThread(); }));
  icon = new NotifyIcon { Icon=System.Drawing.SystemIcons.Application, Text="Pocket Play", Visible=true, ContextMenuStrip=menu };
  icon.DoubleClick += (_,_) => Show();
  timer.Tick += (_,_) => TrackWindow(); timer.Start();
  icon.ShowBalloonTip(5000,"Pocket Play","右键托盘图标，选择启动 / 安装 Android。",ToolTipIcon.Info);
 }
 async Task Guard(Func<Task> action) {
  if (busy) return; busy=true; status.Text="正在处理，请稍候…";
  try { await action(); } catch(Exception e) { MessageBox.Show(e.Message,"Pocket Play",MessageBoxButtons.OK,MessageBoxIcon.Error); }
  finally { busy=false; status.Text="Pocket Play · Android"; }
 }
 ProcessStartInfo Info(string file, IEnumerable<string> args) {
  var p = new ProcessStartInfo(file) { UseShellExecute=false, CreateNoWindow=true, RedirectStandardOutput=true, RedirectStandardError=true, RedirectStandardInput=true };
  foreach(var arg in args) p.ArgumentList.Add(arg);
  p.Environment["ANDROID_HOME"]=Sdk; p.Environment["ANDROID_SDK_ROOT"]=Sdk; p.Environment["ANDROID_AVD_HOME"]=avdHome;
  p.Environment["JAVA_HOME"]=Path.Combine(AppContext.BaseDirectory,"runtime","java");
  p.Environment["PATH"]=Path.Combine(p.Environment["JAVA_HOME"]!,"bin")+";"+Environment.GetEnvironmentVariable("PATH");
  return p;
 }
 async Task Run(string file, string[] args, string input="", int timeout=1800) {
  // sdkmanager and avdmanager are batch files; cmd.exe needs an outer quote pair.
  ProcessStartInfo info;
  if (file.EndsWith(".bat")) {
   info=Info(Environment.GetEnvironmentVariable("COMSPEC") ?? "cmd.exe",Array.Empty<string>());
   info.Arguments="/d /s /c \"\""+file+"\" "+string.Join(" ",args.Select(a=>"\""+a+"\""))+"\"";
  } else info=Info(file,args);
  using var process=Process.Start(info) ?? throw new Exception("无法启动 "+file);
  var output=process.StandardOutput.ReadToEndAsync(); var error=process.StandardError.ReadToEndAsync();
  try {
   await process.StandardInput.WriteAsync(input); process.StandardInput.Close();
   using var cancel = new CancellationTokenSource(TimeSpan.FromSeconds(timeout)); await process.WaitForExitAsync(cancel.Token);
  } catch { try { process.Kill(true); } catch {} throw; }
  var text=await output+await error; await File.AppendAllTextAsync(Path.Combine(root,"setup.log"),text);
  if (process.ExitCode!=0) throw new Exception($"操作失败 ({process.ExitCode})。查看 {Path.Combine(root,"setup.log")}\n"+text[^Math.Min(text.Length,1600)..]);
 }
 async Task Start() {
  if (emulator is { HasExited:false }) { Show(); return; }
  if (!File.Exists(Config) || !File.Exists(Path.Combine(Sdk,"emulator","emulator.exe"))) {
   if (MessageBox.Show("将下载数 GB 官方 Android 15 / Google Play 镜像，需要至少 15 GB 可用空间。\n继续表示同意 Android SDK 许可：\nhttps://developer.android.com/studio/terms\n\nWindows 需要在 BIOS 开启虚拟化，并启用 Windows Hypervisor Platform 后重启。", "首次安装",MessageBoxButtons.OKCancel)!=DialogResult.OK) return;
   await Task.Run(()=>Copy(Path.Combine(AppContext.BaseDirectory,"runtime","cmdline-tools"),Path.Combine(Sdk,"cmdline-tools","latest")));
   Directory.CreateDirectory(avdHome);
   string manager=Path.Combine(Sdk,"cmdline-tools","latest","bin","sdkmanager.bat");
   await Run(manager,new[]{"--sdk_root="+Sdk,"--licenses"},string.Concat(Enumerable.Repeat("y\n",100)));
   await Run(manager,new[]{"--sdk_root="+Sdk,"emulator","platform-tools","system-images;android-35;google_apis_playstore;x86_64"});
   if (!File.Exists(Config)) await Run(Path.Combine(Sdk,"cmdline-tools","latest","bin","avdmanager.bat"),new[]{"create","avd","-n","PocketPlay_API35","-k","system-images;android-35;google_apis_playstore;x86_64","-d","pixel_6"},"no\n");
   var settings=new Dictionary<string,string> { ["hw.keyboard"]="yes",["showDeviceFrame"]="no",["hw.ramSize"]="4096",["hw.cpu.ncore"]="4",["PlayStore.enabled"]="yes" };
   var lines=File.ReadAllLines(Config).Where(l=>!settings.ContainsKey(l.Split('=')[0])).ToList(); lines.AddRange(settings.Select(p=>p.Key+"="+p.Value)); File.WriteAllLines(Config,lines,new UTF8Encoding(false));
  }
  var info=Info(Path.Combine(Sdk,"emulator","emulator.exe"),new[]{"-avd","PocketPlay_API35","-port","5554","-gpu","auto","-no-boot-anim","-camera-front","webcam0"});
  emulator=Process.Start(info) ?? throw new Exception("模拟器启动失败");
  emulator.StandardInput.Close();
  _=Pump(emulator.StandardOutput); _=Pump(emulator.StandardError);
  await Task.Delay(2500);
  if(emulator.HasExited) throw new Exception("模拟器已退出。检查虚拟化设置以及 emulator.log。");
 }
 readonly SemaphoreSlim logLock=new(1);
 async Task Pump(StreamReader reader) { try { while(await reader.ReadLineAsync() is string line) { await logLock.WaitAsync(); try { await File.AppendAllTextAsync(Path.Combine(root,"emulator.log"),line+Environment.NewLine); } finally {logLock.Release();} } } catch {} }
 async Task Stop() {
  if(emulator is null || emulator.HasExited) return;
  await Run(Path.Combine(Sdk,"platform-tools","adb.exe"),new[]{"-s","emulator-5554","emu","kill"},timeout:15);
  using var cancel=new CancellationTokenSource(TimeSpan.FromSeconds(90)); await emulator.WaitForExitAsync(cancel.Token); window=IntPtr.Zero;
 }
 static void Copy(string source,string target) { Directory.CreateDirectory(target); foreach(string f in Directory.GetFiles(source)) File.Copy(f,Path.Combine(target,Path.GetFileName(f)),true); foreach(string d in Directory.GetDirectories(source)) Copy(d,Path.Combine(target,Path.GetFileName(d))); }
 void TrackWindow() {
  if(emulator is null || emulator.HasExited || quitting) return;
  EnumWindows((h,_)=>{ var title=new StringBuilder(512); GetWindowText(h,title,512); if(title.ToString().Contains("PocketPlay_API35")) { window=h; long style=GetWindowLongPtr(h,-20).ToInt64(); SetWindowLongPtr(h,-20,new IntPtr((style|0x80)&~0x40000));
    // Disable native close: hiding via tray avoids destroying the emulator process.
    EnableMenuItem(GetSystemMenu(h,false),0xF060,1); return false; } return true; },IntPtr.Zero);
 }
 void Show() { if(window!=IntPtr.Zero) {ShowWindow(window,9); SetForegroundWindow(window);} }
 void Hide() {if(window!=IntPtr.Zero) ShowWindow(window,0);}
 protected override void Dispose(bool disposing) {if(disposing){timer.Dispose();icon.Dispose();}base.Dispose(disposing);}
 delegate bool EnumProc(IntPtr h,IntPtr p);
 [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb,IntPtr p);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h,StringBuilder s,int n);
 [DllImport("user32.dll")] static extern IntPtr GetWindowLongPtr(IntPtr h,int n);
 [DllImport("user32.dll")] static extern IntPtr SetWindowLongPtr(IntPtr h,int n,IntPtr v);
 [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h,int cmd);
 [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] static extern IntPtr GetSystemMenu(IntPtr h,bool revert);
 [DllImport("user32.dll")] static extern uint EnableMenuItem(IntPtr h,uint id,uint flags);
}
