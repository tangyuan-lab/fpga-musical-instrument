"""Tang Mega FPGA 电子乐器上位机图形界面。

界面只负责设备控制和文件管理：完整 MIDI 文件、FTB 单周期音色以及播放控制
通过串口发送给 FPGA；MIDI 解析、声部调度和音频合成仍在 FPGA 内完成。

本文件只使用 Python 自带的 Tkinter/ttk，不依赖额外的界面框架。这样在用户的
Windows 电脑上安装 ``pyserial`` 后即可运行，也避免为了界面增加新的部署风险。
"""

from __future__ import annotations

import threading
from datetime import datetime
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from .serial_link import FpgaSerialLink, list_serial_ports, validate_midi_type0
from .timbre_file import decode_ftb


class ControlWindow(tk.Tk):
    """提供串口连接、MIDI/FTB 上传、播放控制和 FPGA 状态反馈的窗口。"""

    BG = "#0b1220"
    PANEL = "#111c2e"
    PANEL_2 = "#16243a"
    FIELD = "#0d1728"
    BORDER = "#263b59"
    TEXT = "#e8f0ff"
    MUTED = "#91a5c2"
    CYAN = "#35c2ee"
    GREEN = "#35d39a"
    ORANGE = "#f2b84b"
    RED = "#ff6b78"

    def __init__(self) -> None:
        super().__init__()
        self.title("Tang Mega FPGA 电子乐器控制台")
        self.geometry("1120x820")
        self.minsize(980, 720)
        self.configure(bg=self.BG)

        self.port_var = tk.StringVar()
        self.midi_var = tk.StringVar()
        self.ftb_var = tk.StringVar()
        self.timbre_choice_var = tk.StringVar(value="0 · 三角波")
        self.status_var = tk.StringVar(value="请选择板载 USB-C 对应的 COM 口")
        self.connection_var = tk.StringVar(value="未连接")
        self.midi_info_var = tk.StringVar(value="还没有选择 MIDI 文件")
        self.ftb_info_var = tk.StringVar(value="还没有选择 FTB 音色")
        self.progress_text_var = tk.StringVar(value="等待操作")
        self.progress_var = tk.DoubleVar(value=0.0)
        self.auto_status_var = tk.BooleanVar(value=False)

        self._link: FpgaSerialLink | None = None
        self._link_port: str | None = None
        self._port_map: dict[str, str] = {}
        self._link_lock = threading.Lock()
        self._busy = False
        self._closing = False
        self._action_buttons: list[tk.Widget] = []
        self._status_value_vars: dict[str, tk.StringVar] = {}

        self._setup_style()
        self._build()
        self.refresh_ports()
        self.after(2500, self._auto_status_tick)
        self.protocol("WM_DELETE_WINDOW", self._on_close)

    def _setup_style(self) -> None:
        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure("App.TFrame", background=self.BG)
        style.configure("Panel.TFrame", background=self.PANEL)
        style.configure("TLabel", background=self.BG, foreground=self.TEXT,
                        font=("Segoe UI", 10))
        style.configure("Muted.TLabel", background=self.BG, foreground=self.MUTED,
                        font=("Segoe UI", 9))
        style.configure("Panel.TLabel", background=self.PANEL, foreground=self.TEXT,
                        font=("Segoe UI", 10))
        style.configure("PanelMuted.TLabel", background=self.PANEL, foreground=self.MUTED,
                        font=("Segoe UI", 9))
        style.configure("Title.TLabel", background=self.BG, foreground=self.TEXT,
                        font=("Segoe UI", 21, "bold"))
        style.configure("Subtitle.TLabel", background=self.BG, foreground=self.MUTED,
                        font=("Segoe UI", 10))
        style.configure("Section.TLabel", background=self.PANEL, foreground=self.TEXT,
                        font=("Segoe UI", 12, "bold"))
        style.configure("TEntry", fieldbackground=self.FIELD, foreground=self.TEXT,
                        insertcolor=self.TEXT, bordercolor=self.BORDER,
                        lightcolor=self.BORDER, darkcolor=self.BORDER)
        style.configure("TCombobox", fieldbackground=self.FIELD, foreground=self.TEXT,
                        background=self.FIELD, arrowcolor=self.CYAN,
                        bordercolor=self.BORDER, lightcolor=self.BORDER,
                        darkcolor=self.BORDER)
        style.map("TCombobox", fieldbackground=[("readonly", self.FIELD)],
                  foreground=[("readonly", self.TEXT)])
        style.configure("Primary.TButton", background=self.CYAN, foreground="#06111d",
                        bordercolor=self.CYAN, padding=(12, 7),
                        font=("Segoe UI", 10, "bold"))
        style.map("Primary.TButton", background=[("active", "#6bd9f5"),
                                                   ("disabled", "#34536a")])
        style.configure("Success.TButton", background=self.GREEN, foreground="#06111d",
                        bordercolor=self.GREEN, padding=(12, 7),
                        font=("Segoe UI", 10, "bold"))
        style.map("Success.TButton", background=[("active", "#79e8bd"),
                                                   ("disabled", "#345c55")])
        style.configure("Danger.TButton", background="#e45465", foreground="#ffffff",
                        bordercolor="#e45465", padding=(12, 7),
                        font=("Segoe UI", 10, "bold"))
        style.map("Danger.TButton", background=[("active", "#ff7b88"),
                                                  ("disabled", "#633c49")])
        style.configure("Secondary.TButton", background="#16243a", foreground=self.TEXT,
                        bordercolor=self.BORDER, padding=(10, 6))
        style.map("Secondary.TButton", background=[("active", "#213754"),
                                                    ("disabled", "#172337")])
        style.configure("Horizontal.TProgressbar", troughcolor=self.FIELD,
                        background=self.CYAN, bordercolor=self.BORDER,
                        lightcolor=self.CYAN, darkcolor=self.CYAN, thickness=10)
        style.configure("TCheckbutton", background=self.PANEL, foreground=self.TEXT,
                        font=("Segoe UI", 9))
        style.map("TCheckbutton", background=[("active", self.PANEL)])

    def _panel(self, parent: tk.Misc, row: int, column: int) -> ttk.Frame:
        panel = ttk.Frame(parent, style="Panel.TFrame", padding=14)
        panel.grid(row=row, column=column, sticky="nsew", padx=6, pady=6)
        return panel

    def _build(self) -> None:
        self.columnconfigure(0, weight=1)
        self.rowconfigure(1, weight=1)

        header = ttk.Frame(self, style="App.TFrame", padding=(24, 20, 24, 10))
        header.grid(row=0, column=0, sticky="ew")
        header.columnconfigure(0, weight=1)
        ttk.Label(header, text="FPGA 电子乐器控制台", style="Title.TLabel").grid(
            row=0, column=0, sticky="w")
        ttk.Label(header, text="MIDI 乐谱与单周期音色上传 · FPGA 内部解析、调度和实时合成",
                  style="Subtitle.TLabel").grid(row=1, column=0, sticky="w", pady=(3, 0))
        status_box = ttk.Frame(header, style="App.TFrame")
        status_box.grid(row=0, column=1, rowspan=2, sticky="e", padx=(20, 0))
        self.connection_dot = tk.Canvas(status_box, width=14, height=14, bg=self.BG,
                                        highlightthickness=0)
        self.connection_dot.grid(row=0, column=0, padx=(0, 6))
        self.connection_dot_id = self.connection_dot.create_oval(2, 2, 12, 12,
                                                                  fill=self.ORANGE,
                                                                  outline="")
        ttk.Label(status_box, textvariable=self.connection_var, style="Subtitle.TLabel").grid(
            row=0, column=1, sticky="e")

        content = ttk.Frame(self, style="App.TFrame", padding=(18, 4, 18, 14))
        content.grid(row=1, column=0, sticky="nsew")
        content.columnconfigure(0, weight=0, minsize=390)
        content.columnconfigure(1, weight=1)
        content.rowconfigure(0, weight=1)
        left = ttk.Frame(content, style="App.TFrame")
        left.grid(row=0, column=0, sticky="nsew")
        left.columnconfigure(0, weight=1)
        right = ttk.Frame(content, style="App.TFrame")
        right.grid(row=0, column=1, sticky="nsew")
        right.columnconfigure(0, weight=1)
        right.rowconfigure(2, weight=1)

        self._build_connection_panel(left)
        self._build_midi_panel(left)
        self._build_timbre_panel(left)
        self._build_playback_panel(left)
        self._build_status_panel(right)
        self._build_progress_panel(right)
        self._build_log_panel(right)

        footer = ttk.Frame(self, style="App.TFrame", padding=(24, 0, 24, 13))
        footer.grid(row=2, column=0, sticky="ew")
        ttk.Label(footer,
                  text="提示：选择 NEO Dock 板载 USB-C 的 FPGA UART/BL616 端口；instrument_full 位流先按 AB13 切到 MIDI 模式。",
                  style="Muted.TLabel").pack(side="left")

    def _build_connection_panel(self, parent: ttk.Frame) -> None:
        panel = self._panel(parent, 0, 0)
        panel.columnconfigure(1, weight=1)
        ttk.Label(panel, text="设备连接", style="Section.TLabel").grid(
            row=0, column=0, columnspan=3, sticky="w")
        ttk.Label(panel, text="板载 USB-C · 115200 / 8N1", style="PanelMuted.TLabel").grid(
            row=1, column=0, columnspan=3, sticky="w", pady=(2, 10))
        ttk.Label(panel, text="COM 口", style="Panel.TLabel").grid(row=2, column=0, sticky="w")
        self.port_box = ttk.Combobox(panel, textvariable=self.port_var, width=24,
                                     state="readonly")
        self.port_box.grid(row=2, column=1, sticky="ew", padx=8)
        refresh = ttk.Button(panel, text="刷新", style="Secondary.TButton",
                             command=self.refresh_ports)
        refresh.grid(row=2, column=2)
        self._action_buttons.append(refresh)
        connect = ttk.Button(panel, text="连接并测试", style="Primary.TButton",
                             command=self.connect_device)
        connect.grid(row=3, column=0, columnspan=2, sticky="ew", pady=(10, 0))
        self._action_buttons.append(connect)
        disconnect = ttk.Button(panel, text="断开", style="Secondary.TButton",
                                command=self.disconnect_device)
        disconnect.grid(row=3, column=2, sticky="ew", padx=(8, 0), pady=(10, 0))
        self._action_buttons.append(disconnect)
        ping = ttk.Button(panel, text="PING", style="Secondary.TButton", command=self.ping)
        ping.grid(row=4, column=0, sticky="ew", pady=(8, 0))
        self._action_buttons.append(ping)
        status = ttk.Button(panel, text="读取状态", style="Secondary.TButton",
                            command=self.read_status)
        status.grid(row=4, column=1, columnspan=2, sticky="ew", padx=(8, 0), pady=(8, 0))
        self._action_buttons.append(status)
        ttk.Checkbutton(panel, text="每 3 秒自动刷新 FPGA 状态",
                        variable=self.auto_status_var).grid(row=5, column=0,
                                                            columnspan=3, sticky="w",
                                                            pady=(10, 0))

    def _build_midi_panel(self, parent: ttk.Frame) -> None:
        panel = self._panel(parent, 1, 0)
        panel.columnconfigure(0, weight=1)
        ttk.Label(panel, text="MIDI 乐谱", style="Section.TLabel").grid(
            row=0, column=0, columnspan=2, sticky="w")
        ttk.Label(panel, text="只上传标准 MIDI Type 0，解析和播放由 FPGA 完成",
                  style="PanelMuted.TLabel").grid(row=1, column=0, columnspan=2,
                                                   sticky="w", pady=(2, 8))
        ttk.Entry(panel, textvariable=self.midi_var).grid(row=2, column=0, sticky="ew",
                                                          padx=(0, 8))
        browse = ttk.Button(panel, text="选择文件", style="Secondary.TButton",
                            command=self.choose_midi)
        browse.grid(row=2, column=1, sticky="ew")
        self._action_buttons.append(browse)
        ttk.Label(panel, textvariable=self.midi_info_var, style="PanelMuted.TLabel",
                  wraplength=350).grid(row=3, column=0, columnspan=2, sticky="w", pady=(6, 8))
        upload = ttk.Button(panel, text="仅上传到 FPGA", style="Secondary.TButton",
                            command=self.upload_midi)
        upload.grid(row=4, column=0, sticky="ew", padx=(0, 8))
        self._action_buttons.append(upload)
        upload_play = ttk.Button(panel, text="上传并播放", style="Success.TButton",
                                 command=self.send_midi)
        upload_play.grid(row=4, column=1, sticky="ew")
        self._action_buttons.append(upload_play)

    def _build_timbre_panel(self, parent: ttk.Frame) -> None:
        panel = self._panel(parent, 2, 0)
        panel.columnconfigure(0, weight=1)
        ttk.Label(panel, text="自定义音色", style="Section.TLabel").grid(
            row=0, column=0, columnspan=2, sticky="w")
        ttk.Label(panel, text="FTB = 256 点单周期波表 + ADSR 参数，不上传整段录音",
                  style="PanelMuted.TLabel").grid(row=1, column=0, columnspan=2,
                                                   sticky="w", pady=(2, 8))
        ttk.Entry(panel, textvariable=self.ftb_var).grid(row=2, column=0, sticky="ew",
                                                         padx=(0, 8))
        browse = ttk.Button(panel, text="选择文件", style="Secondary.TButton",
                            command=self.choose_ftb)
        browse.grid(row=2, column=1, sticky="ew")
        self._action_buttons.append(browse)
        ttk.Label(panel, textvariable=self.ftb_info_var, style="PanelMuted.TLabel",
                  wraplength=350).grid(row=3, column=0, columnspan=2, sticky="w", pady=(6, 8))
        upload = ttk.Button(panel, text="上传 FTB 音色", style="Primary.TButton",
                            command=self.upload_ftb)
        upload.grid(row=4, column=0, columnspan=2, sticky="ew")
        self._action_buttons.append(upload)

    def _build_playback_panel(self, parent: ttk.Frame) -> None:
        panel = self._panel(parent, 3, 0)
        panel.columnconfigure(1, weight=1)
        ttk.Label(panel, text="播放控制", style="Section.TLabel").grid(
            row=0, column=0, columnspan=3, sticky="w")
        ttk.Label(panel, text="播放前请先上传 MIDI；音色 2 需要先上传 FTB",
                  style="PanelMuted.TLabel").grid(row=1, column=0, columnspan=3,
                                                   sticky="w", pady=(2, 8))
        ttk.Label(panel, text="播放音色", style="Panel.TLabel").grid(row=2, column=0, sticky="w")
        ttk.Combobox(panel, textvariable=self.timbre_choice_var,
                     values=("0 · 三角波", "1 · 柔和方波", "2 · 自定义 FTB"),
                     state="readonly", width=20).grid(row=2, column=1, columnspan=2,
                                                      sticky="ew", padx=(8, 0))
        play = ttk.Button(panel, text="播放", style="Success.TButton", command=self.play)
        play.grid(row=3, column=0, columnspan=2, sticky="ew", pady=(10, 0))
        self._action_buttons.append(play)
        stop = ttk.Button(panel, text="停止", style="Danger.TButton", command=self.stop)
        stop.grid(row=3, column=2, sticky="ew", padx=(8, 0), pady=(10, 0))
        self._action_buttons.append(stop)

    def _build_status_panel(self, parent: ttk.Frame) -> None:
        panel = self._panel(parent, 0, 0)
        panel.columnconfigure(0, weight=1)
        panel.columnconfigure(1, weight=1)
        ttk.Label(panel, text="FPGA 状态", style="Section.TLabel").grid(
            row=0, column=0, columnspan=2, sticky="w")
        ttk.Label(panel, text="状态来自 FPGA STATUS 帧；电脑不会参与 PCM 音频生成。",
                  style="PanelMuted.TLabel").grid(row=1, column=0, columnspan=2,
                                                   sticky="w", pady=(2, 10))
        cards = (
            ("audio", "音频链路", "等待检测"),
            ("file", "MIDI 文件", "未接收"),
            ("parser", "解析器", "空闲"),
            ("playing", "播放状态", "已停止"),
            ("voices", "当前声部", "0"),
            ("timbre", "当前音色", "三角波"),
        )
        for index, (key, title, initial) in enumerate(cards):
            row, column = 2 + index // 2, index % 2
            card = tk.Frame(panel, bg="#16243a", highlightbackground=self.BORDER,
                            highlightthickness=1)
            card.grid(row=row, column=column, sticky="ew", padx=4, pady=4, ipady=6)
            tk.Label(card, text=title, bg="#16243a", fg=self.MUTED,
                     font=("Segoe UI", 9)).pack(anchor="w", padx=10, pady=(7, 0))
            value_var = tk.StringVar(value=initial)
            self._status_value_vars[key] = value_var
            tk.Label(card, textvariable=value_var, bg="#16243a", fg=self.TEXT,
                     font=("Segoe UI", 13, "bold")).pack(anchor="w", padx=10, pady=(1, 7))

    def _build_progress_panel(self, parent: ttk.Frame) -> None:
        panel = self._panel(parent, 1, 0)
        panel.columnconfigure(0, weight=1)
        ttk.Label(panel, text="传输进度", style="Section.TLabel").grid(row=0, column=0,
                                                                        sticky="w")
        ttk.Label(panel, textvariable=self.progress_text_var, style="PanelMuted.TLabel").grid(
            row=1, column=0, sticky="w", pady=(2, 7))
        ttk.Progressbar(panel, variable=self.progress_var, maximum=100,
                        style="Horizontal.TProgressbar").grid(row=2, column=0,
                                                               sticky="ew")

    def _build_log_panel(self, parent: ttk.Frame) -> None:
        panel = self._panel(parent, 2, 0)
        panel.columnconfigure(0, weight=1)
        panel.rowconfigure(1, weight=1)
        ttk.Label(panel, text="操作日志", style="Section.TLabel").grid(row=0, column=0,
                                                                        sticky="w")
        log_frame = tk.Frame(panel, bg=self.FIELD)
        log_frame.grid(row=1, column=0, sticky="nsew", pady=(8, 0))
        log_frame.rowconfigure(0, weight=1)
        log_frame.columnconfigure(0, weight=1)
        self.log_text = tk.Text(log_frame, height=9, bg=self.FIELD, fg=self.TEXT,
                                insertbackground=self.TEXT, relief="flat", bd=0,
                                wrap="word", font=("Consolas", 9), padx=10, pady=8,
                                state="disabled")
        self.log_text.grid(row=0, column=0, sticky="nsew")
        scrollbar = ttk.Scrollbar(log_frame, orient="vertical", command=self.log_text.yview)
        scrollbar.grid(row=0, column=1, sticky="ns")
        self.log_text.configure(yscrollcommand=scrollbar.set)
        self._log("界面已启动。请选择板载 USB-C 对应的 COM 口，然后点击“连接并测试”。")

    def _ui(self, callback) -> None:
        """把后台线程的更新安全地投递到 Tk 主线程。"""

        if not self._closing:
            self.after(0, callback)

    def _log(self, message: str) -> None:
        if self._closing:
            return
        stamp = datetime.now().strftime("%H:%M:%S")
        self.log_text.configure(state="normal")
        self.log_text.insert("end", f"[{stamp}] {message}\n")
        self.log_text.see("end")
        self.log_text.configure(state="disabled")

    def _set_connection_state(self, text: str, color: str) -> None:
        self.connection_var.set(text)
        self.connection_dot.itemconfigure(self.connection_dot_id, fill=color)

    def _set_busy(self, busy: bool) -> None:
        self._busy = busy
        state = "disabled" if busy else "normal"
        for widget in self._action_buttons:
            try:
                widget.configure(state=state)
            except tk.TclError:
                pass

    def _selected_timbre_id(self) -> int:
        value = self.timbre_choice_var.get().strip()
        try:
            return int(value.split("·", 1)[0].strip())
        except (ValueError, IndexError):
            return 0

    def _ensure_link(self, port_name: str) -> FpgaSerialLink:
        if self._link is not None and self._link_port == port_name:
            return self._link
        if self._link is not None:
            self._link.close()
        self._link = FpgaSerialLink(port_name)
        self._link_port = port_name
        return self._link

    def _run_task(self, title: str, action, *, success: str | None = None,
                  silent: bool = False) -> None:
        """单线程执行一次串口操作，防止多个按钮同时占用同一个 COM 口。"""

        if self._busy:
            self._log("已有操作正在进行，请等待当前操作完成。")
            return
        label = self.port_var.get().strip()
        port_name = self._port_map.get(label, label)
        if not port_name:
            messagebox.showwarning("缺少串口", "请先选择板载 USB-C 对应的 COM 口。")
            return
        self._set_busy(True)
        self._set_connection_state("连接中…", self.ORANGE)
        if not silent:
            self._log(f"开始：{title}")

        def worker() -> None:
            try:
                with self._link_lock:
                    link = self._ensure_link(port_name)
                    action(link)
                self._ui(lambda: self._set_connection_state(f"已连接 · {port_name}", self.GREEN))
                if success:
                    self._ui(lambda: self.status_var.set(success))
                if not silent:
                    message = success or f"{title}完成"
                    self._ui(lambda: self._log(message))
            except Exception as exc:  # noqa: BLE001 - 统一显示串口/协议错误
                error_text = str(exc)
                self._ui(lambda: self._set_connection_state("连接/操作失败", self.RED))
                if not silent:
                    self._ui(lambda: self._log(f"失败：{error_text}"))
                    self._ui(lambda: messagebox.showerror("操作失败", error_text))
                    self._ui(lambda: self.status_var.set(f"错误：{error_text}"))
                else:
                    self._ui(lambda: self.status_var.set(f"自动读取失败：{error_text}"))
            finally:
                self._ui(lambda: self._set_busy(False))

        threading.Thread(target=worker, daemon=True, name="fpga-gui-worker").start()

    def refresh_ports(self) -> None:
        ports = list_serial_ports()
        labels = [f"{name} | {description}" if description else name
                  for name, description in ports]
        self._port_map = {label: name for label, (name, _) in zip(labels, ports)}
        self.port_box["values"] = labels
        if self.port_var.get() not in labels:
            self.port_var.set(labels[0] if labels else "")
        if not labels:
            self._set_connection_state("未发现 COM 口", self.RED)
            self.status_var.set("没有发现串口，请连接 NEO Dock 板载 USB-C")
        else:
            self.status_var.set(f"发现 {len(labels)} 个串口，请确认选择的是板载 USB-C UART")

    def connect_device(self) -> None:
        if not self.port_var.get().strip():
            messagebox.showwarning("缺少串口", "请先点击刷新并选择 COM 口。")
            return

        def action(link) -> None:
            link.ping()

        port_name = self._port_map.get(self.port_var.get(), self.port_var.get())
        self._run_task("连接并 PING", action, success=f"连接成功：{port_name}")

    def disconnect_device(self) -> None:
        if self._busy:
            self._log("当前操作尚未完成，暂不执行断开。")
            return
        with self._link_lock:
            if self._link is not None:
                self._link.close()
            self._link = None
            self._link_port = None
        self._set_connection_state("未连接", self.ORANGE)
        self.status_var.set("串口已断开")
        self._log("串口已断开。")

    def ping(self) -> None:
        self._run_task("PING 通信测试", lambda link: link.ping(),
                       success="PING 通信测试完成")

    def choose_midi(self) -> None:
        path = filedialog.askopenfilename(
            title="选择 MIDI Type 0 文件",
            filetypes=[("MIDI Type 0", "*.mid *.midi"), ("所有文件", "*.*")],
        )
        if not path:
            return
        try:
            data = Path(path).read_bytes()
            validate_midi_type0(data)
        except Exception as exc:  # noqa: BLE001 - 文件选择后立即给出可读提示
            self.midi_info_var.set(f"文件无效：{exc}")
            self._log(f"MIDI 校验失败：{exc}")
            messagebox.showerror("MIDI 文件不可用", str(exc))
            return
        self.midi_var.set(path)
        self.midi_info_var.set(f"有效 Type 0 MIDI · {len(data):,} 字节 · FPGA 将自行解析")
        self._log(f"已选择 MIDI：{Path(path).name}（{len(data):,} 字节）")

    def _midi_bytes(self) -> tuple[Path, bytes] | None:
        path = Path(self.midi_var.get().strip())
        if not path.is_file():
            messagebox.showwarning("缺少文件", "请先选择 MIDI Type 0 文件。")
            return None
        try:
            data = path.read_bytes()
            validate_midi_type0(data)
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("MIDI 文件不可用", str(exc))
            return None
        return path, data

    def _set_progress(self, done: int, total: int, label: str) -> None:
        percent = 100.0 if total == 0 else done * 100.0 / total
        self._ui(lambda: self.progress_var.set(percent))
        self._ui(lambda: self.progress_text_var.set(
            f"{label}：{done:,}/{total:,} 字节（{percent:.0f}%）"))

    def upload_midi(self) -> None:
        selected = self._midi_bytes()
        if selected is None:
            return
        path, data = selected

        def action(link) -> None:
            link.ping()
            link.send_midi_file(data, timbre_id=self._selected_timbre_id(), start_play=False,
                                progress=lambda done, total: self._set_progress(
                                    done, total, "MIDI 上传"))

        self.progress_var.set(0)
        self.progress_text_var.set("准备上传 MIDI…")
        self._run_task("上传 MIDI", action,
                       success=f"MIDI 已上传：{path.name}（等待播放命令）")

    def send_midi(self) -> None:
        selected = self._midi_bytes()
        if selected is None:
            return
        path, data = selected

        def action(link) -> None:
            link.ping()
            link.send_midi_file(data, timbre_id=self._selected_timbre_id(), start_play=True,
                                progress=lambda done, total: self._set_progress(
                                    done, total, "MIDI 上传"))

        self.progress_var.set(0)
        self.progress_text_var.set("准备上传并播放…")
        self._run_task("上传并播放 MIDI", action,
                       success=f"MIDI 已上传并开始播放：{path.name}")

    def choose_ftb(self) -> None:
        path = filedialog.askopenfilename(
            title="选择 FTB 单周期音色",
            filetypes=[("FTB wavetable", "*.ftb"), ("所有文件", "*.*")],
        )
        if not path:
            return
        try:
            timbre = decode_ftb(Path(path).read_bytes())
        except Exception as exc:  # noqa: BLE001
            self.ftb_info_var.set(f"文件无效：{exc}")
            self._log(f"FTB 校验失败：{exc}")
            messagebox.showerror("FTB 文件不可用", str(exc))
            return
        self.ftb_var.set(path)
        self.ftb_info_var.set(
            f"{timbre.name or '未命名'} · 256 点 · 起音 {timbre.attack} · 释音 {timbre.release}")
        self._log(f"已选择 FTB：{Path(path).name}")

    def upload_ftb(self) -> None:
        path = Path(self.ftb_var.get().strip())
        if not path.is_file():
            messagebox.showwarning("缺少文件", "请先选择 FTB 音色文件。")
            return
        try:
            data = path.read_bytes()
            timbre = decode_ftb(data)
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("FTB 文件不可用", str(exc))
            return

        def action(link) -> None:
            link.ping()
            link.upload_ftb(data, progress=lambda done, total: self._set_progress(
                done, total, "FTB 上传"))

        self.progress_var.set(0)
        self.progress_text_var.set("准备上传 FTB…")
        self._run_task("上传 FTB 音色", action,
                       success=f"FTB 已启用：{timbre.name or path.name}")

    def play(self) -> None:
        timbre_id = self._selected_timbre_id()
        self._run_task("发送播放命令", lambda link: link.play(timbre_id),
                       success=f"播放命令已发送（音色 {timbre_id}）")

    def stop(self) -> None:
        self._run_task("发送停止命令", lambda link: link.stop(),
                       success="停止命令已发送")

    def read_status(self, silent: bool = False) -> None:
        def action(link):
            values = link.status()
            self._ui(lambda: self._apply_status(values, silent))

        self._run_task("读取 FPGA 状态", action, silent=silent)

    def _apply_status(self, values: dict[str, int | bool], silent: bool) -> None:
        self._status_value_vars["audio"].set("就绪" if values["audio_ready"] else "启动中")
        self._status_value_vars["file"].set("已接收" if values["file_ready"] else "未接收")
        parser = "解析中" if values["parser_busy"] else (
            "已完成" if values["parser_ready"] else "空闲")
        self._status_value_vars["parser"].set(parser)
        self._status_value_vars["playing"].set("播放中" if values["playing"] else "已停止")
        self._status_value_vars["voices"].set(str(values["voice_count"]))
        names = {0: "三角波", 1: "柔和方波", 2: "自定义 FTB"}
        self._status_value_vars["timbre"].set(names.get(int(values["timbre"]), "未知"))
        if not silent:
            self.status_var.set("状态已更新")

    def _auto_status_tick(self) -> None:
        if not self._closing and self.auto_status_var.get() and not self._busy and self._link:
            self.read_status(silent=True)
        if not self._closing:
            self.after(3000, self._auto_status_tick)

    def _on_close(self) -> None:
        self._closing = True
        with self._link_lock:
            if self._link is not None:
                self._link.close()
                self._link = None
        self.destroy()


def main() -> None:
    """启动 Tkinter 上位机窗口。"""

    ControlWindow().mainloop()


if __name__ == "__main__":
    main()
