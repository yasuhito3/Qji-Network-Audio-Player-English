#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
audio_equalizer_enhanced.py - Enhanced Audio Equalizer
GUI equalizer compatible with existing playback scripts (aplay/ffmpeg)
+ High-shelf filter added (reduces upper-midrange harshness)
"""

import tkinter as tk
from tkinter import ttk, messagebox
import json
import os
import sys
import subprocess
import threading
import time

# 設定ファイルパス
CONFIG_FILE = os.path.expanduser('~/.audio_equalizer_config.json')
FIFO_PATH = '/tmp/audio_equalizer_fifo'

class AudioEqualizerGUI:
    """Audio Equalizer GUI class"""
    
    def __init__(self, root):
        self.root = root
        self.root.title("🎚️ Audio Equalizer Pro")
        self.root.geometry("600x800")
        self.root.resizable(True, True)
        
        # イコライザー設定
        self.eq_enabled = tk.BooleanVar(value=True)
        self.bass_gain = tk.DoubleVar(value=0.0)
        self.treble_gain = tk.DoubleVar(value=0.0)
        
        # ハイシェルフフィルター設定
        self.highshelf_enabled = tk.BooleanVar(value=False)
        self.highshelf_freq = tk.DoubleVar(value=12000.0)  # 12kHz
        self.highshelf_gain = tk.DoubleVar(value=-2.0)     # -2dB
        
        # 設定を読み込み
        self.load_config()
        
        # GUI構築
        self.create_widgets()
        
        # 設定ファイル監視スレッド
        self.running = True
        self.watch_thread = threading.Thread(target=self.watch_config_file, daemon=True)
        self.watch_thread.start()
        
        # 終了時の処理
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
    
    def create_widgets(self):
        """Create widgets"""
        
        # タイトルフレーム
        title_frame = tk.Frame(self.root, bg='#2c3e50', height=60)
        title_frame.pack(fill=tk.X)
        title_frame.pack_propagate(False)
        
        title_label = tk.Label(
            title_frame, 
            text="🎚️ Audio Equalizer Pro",
            font=('Arial', 18, 'bold'),
            bg='#2c3e50',
            fg='white'
        )
        title_label.pack(pady=15)
        
        # メインフレーム
        main_frame = tk.Frame(self.root, bg='#ecf0f1', padx=30, pady=20)
        main_frame.pack(fill=tk.BOTH, expand=True)
        
        # オン・オフスイッチ
        switch_frame = tk.Frame(main_frame, bg='#ecf0f1')
        switch_frame.pack(fill=tk.X, pady=(0, 15))
        
        self.eq_button = tk.Button(
            switch_frame,
            text="⚡ EQ ON",
            font=('Arial', 12, 'bold'),
            bg='#27ae60',
            fg='white',
            activebackground='#229954',
            activeforeground='white',
            relief=tk.RAISED,
            bd=3,
            command=self.toggle_equalizer,
            width=20,
            height=2
        )
        self.eq_button.pack()
        self.update_eq_button()
        
        # 高音スライダー
        treble_frame = tk.LabelFrame(
            main_frame,
            text="🎵 Treble",
            font=('Arial', 11, 'bold'),
            bg='#ecf0f1',
            fg='#34495e',
            padx=15,
            pady=10
        )
        treble_frame.pack(fill=tk.X, pady=8)
        
        self.treble_label = tk.Label(
            treble_frame,
            text=f"{self.treble_gain.get():+.1f} dB",
            font=('Arial', 12, 'bold'),
            bg='#ecf0f1',
            fg='#e74c3c'
        )
        self.treble_label.pack()
        
        self.treble_slider = ttk.Scale(
            treble_frame,
            from_=-12.0,
            to=12.0,
            orient=tk.HORIZONTAL,
            variable=self.treble_gain,
            command=self.on_treble_change,
            length=450
        )
        self.treble_slider.pack(pady=5)
        
        treble_range_label = tk.Label(
            treble_frame,
            text="-12 dB ← → +12 dB",
            font=('Arial', 9),
            bg='#ecf0f1',
            fg='#7f8c8d'
        )
        treble_range_label.pack()
        
        # 低音スライダー
        bass_frame = tk.LabelFrame(
            main_frame, 
            text="🔊 Bass",
            font=('Arial', 11, 'bold'),
            bg='#ecf0f1',
            fg='#34495e',
            padx=15,
            pady=10
        )
        bass_frame.pack(fill=tk.X, pady=8)
        
        self.bass_label = tk.Label(
            bass_frame,
            text=f"{self.bass_gain.get():+.1f} dB",
            font=('Arial', 12, 'bold'),
            bg='#ecf0f1',
            fg='#2980b9'
        )
        self.bass_label.pack()
        
        self.bass_slider = ttk.Scale(
            bass_frame,
            from_=-12.0,
            to=12.0,
            orient=tk.HORIZONTAL,
            variable=self.bass_gain,
            command=self.on_bass_change,
            length=450
        )
        self.bass_slider.pack(pady=5)
        
        bass_range_label = tk.Label(
            bass_frame,
            text="-12 dB ← → +12 dB",
            font=('Arial', 9),
            bg='#ecf0f1',
            fg='#7f8c8d'
        )
        bass_range_label.pack()
        
        # ===== ハイシェルフフィルターセクション =====
        highshelf_section = tk.LabelFrame(
            main_frame,
            text="✨ High-Shelf Filter (upper-midrange smoothing)",
            font=('Arial', 11, 'bold'),
            bg='#ecf0f1',
            fg='#8e44ad',
            padx=15,
            pady=10
        )
        highshelf_section.pack(fill=tk.X, pady=8)
        
        # ハイシェルフ オン/オフスイッチ
        highshelf_switch_frame = tk.Frame(highshelf_section, bg='#ecf0f1')
        highshelf_switch_frame.pack(fill=tk.X, pady=(0, 10))
        
        self.highshelf_button = tk.Button(
            highshelf_switch_frame,
            text="⭕ Hi-Shelf OFF",
            font=('Arial', 10, 'bold'),
            bg='#95a5a6',
            fg='white',
            activebackground='#7f8c8d',
            activeforeground='white',
            relief=tk.RAISED,
            bd=2,
            command=self.toggle_highshelf,
            width=18,
            height=1
        )
        self.highshelf_button.pack()
        self.update_highshelf_button()
        
        # 周波数スライダー
        freq_container = tk.Frame(highshelf_section, bg='#ecf0f1')
        freq_container.pack(fill=tk.X, pady=5)
        
        freq_label_text = tk.Label(
            freq_container,
            text="Cut frequency:",
            font=('Arial', 10),
            bg='#ecf0f1',
            fg='#34495e'
        )
        freq_label_text.pack(anchor=tk.W)
        
        self.highshelf_freq_label = tk.Label(
            freq_container,
            text=f"{self.highshelf_freq.get():.0f} Hz",
            font=('Arial', 11, 'bold'),
            bg='#ecf0f1',
            fg='#9b59b6'
        )
        self.highshelf_freq_label.pack()
        
        self.highshelf_freq_slider = ttk.Scale(
            freq_container,
            from_=6000.0,
            to=16000.0,
            orient=tk.HORIZONTAL,
            variable=self.highshelf_freq,
            command=self.on_highshelf_freq_change,
            length=450
        )
        self.highshelf_freq_slider.pack(pady=3)
        
        freq_range_label = tk.Label(
            freq_container,
            text="6 kHz ← → 16 kHz",
            font=('Arial', 9),
            bg='#ecf0f1',
            fg='#7f8c8d'
        )
        freq_range_label.pack()
        
        # ゲインスライダー
        gain_container = tk.Frame(highshelf_section, bg='#ecf0f1')
        gain_container.pack(fill=tk.X, pady=5)
        
        gain_label_text = tk.Label(
            gain_container,
            text="Cut amount:",
            font=('Arial', 10),
            bg='#ecf0f1',
            fg='#34495e'
        )
        gain_label_text.pack(anchor=tk.W)
        
        self.highshelf_gain_label = tk.Label(
            gain_container,
            text=f"{self.highshelf_gain.get():+.1f} dB",
            font=('Arial', 11, 'bold'),
            bg='#ecf0f1',
            fg='#9b59b6'
        )
        self.highshelf_gain_label.pack()
        
        self.highshelf_gain_slider = ttk.Scale(
            gain_container,
            from_=-12.0,
            to=0.0,
            orient=tk.HORIZONTAL,
            variable=self.highshelf_gain,
            command=self.on_highshelf_gain_change,
            length=450
        )
        self.highshelf_gain_slider.pack(pady=3)
        
        gain_range_label = tk.Label(
            gain_container,
            text="-12 dB (heavy cut) ← → 0 dB (no cut)",
            font=('Arial', 9),
            bg='#ecf0f1',
            fg='#7f8c8d'
        )
        gain_range_label.pack()
        
        # プリセットボタン
        preset_frame = tk.Frame(highshelf_section, bg='#ecf0f1')
        preset_frame.pack(fill=tk.X, pady=(10, 5))
        
        preset_label = tk.Label(
            preset_frame,
            text="Preset:",
            font=('Arial', 9),
            bg='#ecf0f1',
            fg='#7f8c8d'
        )
        preset_label.pack(side=tk.LEFT, padx=(0, 10))
        
        btn_mild = tk.Button(
            preset_frame,
            text="Light (12kHz/-1dB)",
            font=('Arial', 8),
            bg='#bdc3c7',
            command=lambda: self.apply_highshelf_preset(12000, -1.0),
            width=15
        )
        btn_mild.pack(side=tk.LEFT, padx=2)
        
        btn_medium = tk.Button(
            preset_frame,
            text="Standard (12kHz/-2dB)",
            font=('Arial', 8),
            bg='#bdc3c7',
            command=lambda: self.apply_highshelf_preset(12000, -2.0),
            width=15
        )
        btn_medium.pack(side=tk.LEFT, padx=2)
        
        btn_strong = tk.Button(
            preset_frame,
            text="Heavy (10kHz/-3dB)",
            font=('Arial', 8),
            bg='#bdc3c7',
            command=lambda: self.apply_highshelf_preset(10000, -3.0),
            width=15
        )
        btn_strong.pack(side=tk.LEFT, padx=2)
        
        # ===== 終了 =====
        
        # ボタンフレーム
        button_frame = tk.Frame(main_frame, bg='#ecf0f1')
        button_frame.pack(fill=tk.X, pady=(15, 0))
        
        reset_button = tk.Button(
            button_frame,
            text="🔄 Reset",
            font=('Arial', 10, 'bold'),
            bg='#95a5a6',
            fg='white',
            activebackground='#7f8c8d',
            activeforeground='white',
            command=self.reset_settings,
            width=15
        )
        reset_button.pack(side=tk.LEFT, padx=5)
        
        save_button = tk.Button(
            button_frame,
            text="💾 Save",
            font=('Arial', 10, 'bold'),
            bg='#3498db',
            fg='white',
            activebackground='#2980b9',
            activeforeground='white',
            command=self.save_config,
            width=15
        )
        save_button.pack(side=tk.RIGHT, padx=5)
    
    def toggle_equalizer(self):
        """Toggle equalizer on/off"""
        self.eq_enabled.set(not self.eq_enabled.get())
        self.update_eq_button()
        self.save_config()
        
        status = "ON" if self.eq_enabled.get() else "OFF"
        print(f"🎚️ Equalizer: {status}")
    
    def toggle_highshelf(self):
        """Toggle high-shelf filter on/off"""
        self.highshelf_enabled.set(not self.highshelf_enabled.get())
        self.update_highshelf_button()
        self.save_config()
        
        status = "ON" if self.highshelf_enabled.get() else "OFF"
        print(f"✨ High-shelf filter: {status}")
    
    def update_eq_button(self):
        """Update equalizer button label"""
        if self.eq_enabled.get():
            self.eq_button.config(
                text="⚡ EQ ON",
                bg='#27ae60',
                activebackground='#229954'
            )
        else:
            self.eq_button.config(
                text="⭕ EQ OFF",
                bg='#e74c3c',
                activebackground='#c0392b'
            )
    
    def update_highshelf_button(self):
        """Update high-shelf button label"""
        if self.highshelf_enabled.get():
            self.highshelf_button.config(
                text="✨ Hi-Shelf ON",
                bg='#9b59b6',
                activebackground='#8e44ad'
            )
        else:
            self.highshelf_button.config(
                text="⭕ Hi-Shelf OFF",
                bg='#95a5a6',
                activebackground='#7f8c8d'
            )
    
    def on_bass_change(self, value):
        """On bass slider change"""
        val = float(value)
        self.bass_label.config(text=f"{val:+.1f} dB")
        self.save_config()
    
    def on_treble_change(self, value):
        """On treble slider change"""
        val = float(value)
        self.treble_label.config(text=f"{val:+.1f} dB")
        self.save_config()
    
    def on_highshelf_freq_change(self, value):
        """On high-shelf frequency change"""
        val = float(value)
        self.highshelf_freq_label.config(text=f"{val:.0f} Hz")
        self.save_config()
    
    def on_highshelf_gain_change(self, value):
        """On high-shelf gain change"""
        val = float(value)
        self.highshelf_gain_label.config(text=f"{val:+.1f} dB")
        self.save_config()
    
    def apply_highshelf_preset(self, freq, gain):
        """Apply high-shelf preset"""
        self.highshelf_freq.set(freq)
        self.highshelf_gain.set(gain)
        self.highshelf_enabled.set(True)
        self.update_highshelf_button()
        self.highshelf_freq_label.config(text=f"{freq:.0f} Hz")
        self.highshelf_gain_label.config(text=f"{gain:+.1f} dB")
        self.save_config()
        print(f"✨ Preset applied: {freq}Hz / {gain:+.1f}dB")
    
    def reset_settings(self):
        """Reset settings"""
        self.bass_gain.set(0.0)
        self.treble_gain.set(0.0)
        self.bass_label.config(text="+0.0 dB")
        self.treble_label.config(text="+0.0 dB")
        
        self.highshelf_enabled.set(False)
        self.highshelf_freq.set(12000.0)
        self.highshelf_gain.set(-2.0)
        self.update_highshelf_button()
        self.highshelf_freq_label.config(text="12000 Hz")
        self.highshelf_gain_label.config(text="-2.0 dB")
        
        self.save_config()
        messagebox.showinfo("Reset", "Settings have been reset")
    
    def save_config(self):
        """Save settings"""
        config = {
            'enabled': self.eq_enabled.get(),
            'bass_gain': self.bass_gain.get(),
            'treble_gain': self.treble_gain.get(),
            'highshelf_enabled': self.highshelf_enabled.get(),
            'highshelf_freq': self.highshelf_freq.get(),
            'highshelf_gain': self.highshelf_gain.get()
        }
        
        try:
            with open(CONFIG_FILE, 'w') as f:
                json.dump(config, f, indent=2)
            
            status_parts = []
            if config['enabled']:
                status_parts.append(f"Bass={config['bass_gain']:+.1f}dB, Treble={config['treble_gain']:+.1f}dB")
            if config['highshelf_enabled']:
                status_parts.append(f"HighShelf={config['highshelf_freq']:.0f}Hz/{config['highshelf_gain']:+.1f}dB")
            
            status = ", ".join(status_parts) if status_parts else "all OFF"
            print(f"💾 Settings saved: {status}")
        except Exception as e:
            print(f"⚠️ Failed to save settings: {e}")
    
    def load_config(self):
        """Load settings"""
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r') as f:
                    config = json.load(f)
                
                self.eq_enabled.set(config.get('enabled', True))
                self.bass_gain.set(config.get('bass_gain', 0.0))
                self.treble_gain.set(config.get('treble_gain', 0.0))
                
                self.highshelf_enabled.set(config.get('highshelf_enabled', False))
                self.highshelf_freq.set(config.get('highshelf_freq', 12000.0))
                self.highshelf_gain.set(config.get('highshelf_gain', -2.0))
                
                print(f"📂 Settings loaded")
            except Exception as e:
                print(f"⚠️ Failed to load settings: {e}")
    
    def watch_config_file(self):
        """Watch config file for changes"""
        last_mtime = 0
        
        while self.running:
            try:
                if os.path.exists(CONFIG_FILE):
                    mtime = os.path.getmtime(CONFIG_FILE)
                    if mtime > last_mtime:
                        last_mtime = mtime
            except:
                pass
            
            time.sleep(1)
    
    def on_closing(self):
        """Handle window close"""
        self.running = False
        self.save_config()
        self.root.destroy()


class EqualizerCommandLine:
    """Command-line equalizer class"""
    
    @staticmethod
    def get_config():
        """Get current settings"""
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r') as f:
                    return json.load(f)
            except:
                pass
        
        return {
            'enabled': True,
            'bass_gain': 0.0,
            'treble_gain': 0.0,
            'highshelf_enabled': False,
            'highshelf_freq': 12000.0,
            'highshelf_gain': -2.0
        }
    
    @staticmethod
    def get_sox_filters():
        """Generate SoX filter string"""
        config = EqualizerCommandLine.get_config()
        filters = []
        
        # 基本イコライザー
        if config['enabled']:
            # 低音フィルター (100Hz付近)
            bass_gain = config['bass_gain']
            if abs(bass_gain) > 0.1:
                filters.extend(['bass', f"{bass_gain:+.1f}"])
            
            # 高音フィルター (10kHz付近)
            treble_gain = config['treble_gain']
            if abs(treble_gain) > 0.1:
                filters.extend(['treble', f"{treble_gain:+.1f}"])
        
        # ハイシェルフフィルター
        if config.get('highshelf_enabled', False):
            freq = config.get('highshelf_freq', 12000.0)
            gain = config.get('highshelf_gain', -2.0)
            
            if abs(gain) > 0.1:
                # SoXのtrebleコマンドで近似
                filters.extend(['treble', f"{gain:+.1f}", f"{freq:.0f}h"])
        
        return filters
    
    @staticmethod
    def get_ffmpeg_filters():
        """Generate FFmpeg filter string"""
        config = EqualizerCommandLine.get_config()
        filters = []
        
        # 基本イコライザー
        if config['enabled']:
            # 低音フィルター (100Hz付近の広帯域イコライザー)
            bass_gain = config['bass_gain']
            if abs(bass_gain) > 0.1:
                filters.append(f"equalizer=f=100:width_type=o:width=2:g={bass_gain:.1f}")
            
            # 高音フィルター (8kHz付近の広帯域イコライザー)
            treble_gain = config['treble_gain']
            if abs(treble_gain) > 0.1:
                filters.append(f"equalizer=f=8000:width_type=o:width=2:g={treble_gain:.1f}")
        
        # ハイシェルフフィルター
        if config.get('highshelf_enabled', False):
            freq = config.get('highshelf_freq', 12000.0)
            gain = config.get('highshelf_gain', -2.0)
            
            if abs(gain) > 0.1:
                # highshelfフィルター（width=0.4で緩やかな傾斜）
                filters.append(f"highshelf=f={freq:.0f}:g={gain:.1f}:w=0.4")
        
        if filters:
            return ','.join(filters)
        else:
            return None
    
    @staticmethod
    def show_current_settings():
        """Display current settings"""
        config = EqualizerCommandLine.get_config()
        
        print("=" * 70)
        print("🎚️  Audio Equalizer Pro - Current settings")
        print("=" * 70)
        print(f"Basic EQ : {'⚡ ON' if config['enabled'] else '⭕ OFF'}")
        if config['enabled']:
            print(f"  Bass   : {config['bass_gain']:+.1f} dB")
            print(f"  Treble : {config['treble_gain']:+.1f} dB")
        
        print("-" * 70)
        print(f"Hi-Shelf : {'✨ ON' if config.get('highshelf_enabled', False) else '⭕ OFF'}")
        if config.get('highshelf_enabled', False):
            print(f"  Freq   : {config.get('highshelf_freq', 12000):.0f} Hz")
            print(f"  Gain   : {config.get('highshelf_gain', -2.0):+.1f} dB")
        print("=" * 70)
        
        # フィルター情報
        sox_filters = EqualizerCommandLine.get_sox_filters()
        if sox_filters:
            print(f"SoX filters   : {' '.join(sox_filters)}")
        
        ffmpeg_filter = EqualizerCommandLine.get_ffmpeg_filters()
        if ffmpeg_filter:
            print(f"FFmpeg filter : {ffmpeg_filter}")
        
        print("=" * 70)


def main():
    """Main function"""
    if len(sys.argv) > 1:
        if sys.argv[1] == '--show':
            # 現在の設定を表示
            EqualizerCommandLine.show_current_settings()
        
        elif sys.argv[1] == '--sox-filters':
            # SoXフィルターを出力（スクリプトから利用）
            filters = EqualizerCommandLine.get_sox_filters()
            print(' '.join(filters))
        
        elif sys.argv[1] == '--ffmpeg-filter':
            # FFmpegフィルターを出力（スクリプトから利用）
            filter_str = EqualizerCommandLine.get_ffmpeg_filters()
            if filter_str:
                print(filter_str)
        
        elif sys.argv[1] == '--enabled':
            # イコライザーが有効かチェック
            config = EqualizerCommandLine.get_config()
            has_filter = config['enabled'] or config.get('highshelf_enabled', False)
            print('1' if has_filter else '0')
        
        elif sys.argv[1] == '--help':
            print("""
🎚️ Audio Equalizer Pro - Enhanced Audio Equalizer

[New] High-shelf filter included
  Reduces upper-midrange harshness for smoother hi-res playback

Usage:
  python3 audio_equalizer_enhanced.py             Launch GUI
  python3 audio_equalizer_enhanced.py --show      Show current settings
  python3 audio_equalizer_enhanced.py --sox-filters     Print SoX filters
  python3 audio_equalizer_enhanced.py --ffmpeg-filter   Print FFmpeg filter
  python3 audio_equalizer_enhanced.py --enabled         Check enabled state (1/0)

Example usage from a script:
  # SoXでの利用
  EQ_FILTERS=$(python3 audio_equalizer_enhanced.py --sox-filters)
  sox input.wav -t wav - $EQ_FILTERS | aplay

  # FFmpegでの利用
  EQ_FILTER=$(python3 audio_equalizer_enhanced.py --ffmpeg-filter)
  if [ -n "$EQ_FILTER" ]; then
    ffmpeg -i input.mp3 -af "$EQ_FILTER" -f s16le - | aplay -f cd
  fi

About the high-shelf filter:
  - Gently cuts frequencies above the specified threshold
  - Effective for reducing upper-midrange harshness in hi-res sources
  - Presets: Light (12kHz/-1dB), Standard (12kHz/-2dB), Heavy (10kHz/-3dB)
  - Frequency and cut amount can be adjusted per source
            """)
        else:
            print(f"⚠️ Unknown option: {sys.argv[1]}")
            print("Use --help to show help")
    else:
        # GUI起動
        root = tk.Tk()
        app = AudioEqualizerGUI(root)
        print("🎚️ Audio Equalizer Pro started")
        print("✨ High-shelf filter enabled")
        print(f"💾 Config file: {CONFIG_FILE}")
        root.mainloop()


if __name__ == '__main__':
    main()
