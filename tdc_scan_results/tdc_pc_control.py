#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TDC 上位机控制程序 - 通过以太网发送命令和接收数据
支持全双工通信、实时监控和数据分析
"""

import socket
import struct
import time
import threading
import queue
import argparse
import sys
import os
from datetime import datetime

# 可选: 如果需要数据分析和可视化
try:
    import numpy as np
    import matplotlib.pyplot as plt
    ANALYSIS_AVAILABLE = True
except ImportError:
    ANALYSIS_AVAILABLE = False
    print("[WARN] numpy/matplotlib 未安装,数据分析功能不可用")


class TDCController:
    """TDC 以太网控制器 - 全双工通信"""
    
    def __init__(self, host='192.168.2.100', port=1024):
        self.host = host
        self.port = port
        self.socket = None
        self.connected = False
        
        # 数据接收相关
        self.rx_thread = None
        self.rx_running = False
        self.rx_queue = queue.Queue()
        self.data_buffer = []
        
    def connect(self, timeout=5.0):
        """连接到 FPGA"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(timeout)
            self.socket.connect((self.host, self.port))
            self.connected = True
            print(f"[INFO] 成功连接到 {self.host}:{self.port}")
            
            # 启动接收线程
            self.start_receive_thread()
            return True
        except socket.error as e:
            print(f"[ERROR] 连接失败: {e}")
            self.connected = False
            return False
    
    def disconnect(self):
        """断开连接"""
        self.connected = False
        self.stop_receive_thread()
        
        if self.socket:
            try:
                self.socket.shutdown(socket.SHUT_RDWR)
            except:
                pass
            self.socket.close()
            print("[INFO] 已断开连接")
    
    def start_receive_thread(self):
        """启动后台接收线程"""
        if self.rx_thread is None or not self.rx_thread.is_alive():
            self.rx_running = True
            self.rx_thread = threading.Thread(target=self._receive_loop, daemon=True)
            self.rx_thread.start()
            print("[INFO] 数据接收线程已启动")
    
    def stop_receive_thread(self):
        """停止接收线程"""
        self.rx_running = False
        if self.rx_thread and self.rx_thread.is_alive():
            self.rx_thread.join(timeout=2.0)
            print("[INFO] 数据接收线程已停止")
    
    def _receive_loop(self):
        """后台接收循环"""
        print("[INFO] 开始监听数据...")
        
        while self.rx_running and self.connected:
            try:
                # 设置短超时,避免阻塞
                self.socket.settimeout(0.5)
                data = self.socket.recv(4)
                
                if len(data) == 4:
                    value = struct.unpack('>I', data)[0]
                    timestamp = time.time()
                    
                    # 放入队列
                    self.rx_queue.put((timestamp, value))
                    self.data_buffer.append(value)
                    
                    # 解析并显示
                    coarse = (value >> 9) & 0x7FFFFF
                    fine = value & 0x1FF
                    print(f"[RX] Data #{len(self.data_buffer)}: "
                          f"coarse={coarse}, fine={fine}, raw=0x{value:08X}")
                    
                elif len(data) == 0:
                    print("[WARN] 连接关闭")
                    self.connected = False
                    break
                    
            except socket.timeout:
                continue
            except Exception as e:
                if self.rx_running:
                    print(f"[ERROR] 接收数据错误: {e}")
                break
    
    def send_command(self, cmd_data):
        """
        发送命令到 FPGA
        
        Args:
            cmd_data: 32-bit 命令数据
        """
        if not self.connected:
            print("[ERROR] 未连接到设备")
            return False
            
        try:
            data = struct.pack('>I', cmd_data)
            self.socket.sendall(data)
            print(f"[TX] 命令已发送: 0x{cmd_data:08X}")
            return True
        except Exception as e:
            print(f"[ERROR] 发送命令失败: {e}")
            return False
    
    def clear_buffer(self):
        """清空数据缓冲区"""
        self.data_buffer.clear()
        while not self.rx_queue.empty():
            try:
                self.rx_queue.get_nowait()
            except queue.Empty:
                break
        print("[INFO] 数据缓冲区已清空")
    
    def get_received_data(self):
        """获取接收到的所有数据"""
        return self.data_buffer.copy()
    
    def wait_for_data(self, expected_count, timeout=30.0):
        """
        等待接收指定数量的数据
        
        Args:
            expected_count: 期望接收的数据数量
            timeout: 超时时间(秒)
        
        Returns:
            bool: 是否成功接收到足够数据
        """
        start_time = time.time()
        last_count = len(self.data_buffer)
        
        print(f"[INFO] 等待接收 {expected_count} 个数据...")
        
        while len(self.data_buffer) < expected_count:
            if time.time() - start_time > timeout:
                print(f"[WARN] 接收超时,仅收到 {len(self.data_buffer)} 个数据")
                return False
            
            # 检测是否有新数据
            current_count = len(self.data_buffer)
            if current_count != last_count:
                print(f"[INFO] 进度: {current_count}/{expected_count}")
                last_count = current_count
            
            time.sleep(0.1)
        
        print(f"[INFO] 成功接收 {len(self.data_buffer)} 个数据")
        return True
    
    # ========== 命令方法 ==========
    
    def set_sg_delay(self, delay_value):
        """设置 sg_start 延迟 (0-31)"""
        if not (0 <= delay_value <= 31):
            print("[ERROR] sg_delay_value 必须在 0-31 之间")
            return False
        
        cmd = (0b10 << 30) | (delay_value & 0x1F)
        print(f"[CMD] 设置 sg_start 延迟: {delay_value} taps (~{delay_value*78}ps)")
        return self.send_command(cmd)
    
    def set_reset_delay(self, delay_value):
        """设置 reset 延迟 (0-31)"""
        if not (0 <= delay_value <= 31):
            print("[ERROR] rst_delay_value 必须在 0-31 之间")
            return False
        
        cmd = (0b01 << 30) | (delay_value & 0x1F)
        print(f"[CMD] 设置 reset 延迟: {delay_value} taps (~{delay_value*78}ps)")
        return self.send_command(cmd)
    
    def tdc_single_shot(self, phase_value, reset_tdc=False):
        """TDC 单次测量 (phase: 0-140)"""
        if not (0 <= phase_value <= 140):
            print("[ERROR] phase_value 必须在 0-140 之间")
            return False
        
        sel_function = 0
        reset_bit = 1 if reset_tdc else 0
        
        cmd = (0b11 << 30) | (sel_function << 29) | (reset_bit << 28) | (phase_value & 0xFF)
        print(f"[CMD] TDC 单次测量: phase={phase_value} (~{phase_value*17.8:.1f}ps), reset={reset_tdc}")
        return self.send_command(cmd)
    
    def tdc_scan_mode(self, reset_tdc=False):
        """TDC 扫描模式 (phase 0-140, 共141个脉冲)"""
        sel_function = 1
        reset_bit = 1 if reset_tdc else 0
        
        cmd = (0b11 << 30) | (sel_function << 29) | (reset_bit << 28)
        print(f"[CMD] TDC 扫描模式: 将产生 141 个脉冲 (phase 0-140), reset={reset_tdc}")
        return self.send_command(cmd)
    
    def save_data(self, filename=None):
        """保存接收到的数据到文件"""
        if len(self.data_buffer) == 0:
            print("[WARN] 没有数据可保存")
            return None
        
        # 设置保存目录
        save_dir = r"D:\project\vivado_work\TDC\TDC\tdc_scan_results"
        os.makedirs(save_dir, exist_ok=True)
        
        if filename is None:
            filename = f"tdc_data_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        
        # 如果filename不包含路径,则添加save_dir
        if not os.path.dirname(filename):
            filename = os.path.join(save_dir, filename)
        
        try:
            with open(filename, 'w') as f:
                f.write("# Index, Coarse, Fine, Raw_Hex\n")
                for i, value in enumerate(self.data_buffer):
                    coarse = (value >> 9) & 0x7FFFFF
                    fine = value & 0x1FF
                    f.write(f"{i},{coarse},{fine},{value:08X}\n")
            
            print(f"[INFO] 数据已保存到: {filename}")
            return filename
        except Exception as e:
            print(f"[ERROR] 保存文件失败: {e}")
            return None


class TDCAnalyzer:
    """TDC 数据分析器"""
    
    def __init__(self, data_buffer):
        self.data = np.array(data_buffer)
        self.coarse = (self.data >> 9) & 0x7FFFFF
        self.fine = self.data & 0x1FF
        
        # 时间常数
        self.T_CLK = 2.5  # ns
        self.T_PHASE = 17.8  # ps
        self.TDC_BIN = 53.0  # ps (理论)
    
    def analyze(self):
        """分析数据"""
        print("\n" + "="*60)
        print("TDC 数据分析")
        print("="*60)
        print(f"样本数量: {len(self.data)}")
        print(f"粗计数范围: {self.coarse.min()} - {self.coarse.max()}")
        print(f"细计数范围: {self.fine.min()} - {self.fine.max()}")
        
        # 计算时间
        coarse_time = self.coarse * self.T_CLK * 1000  # ps
        fine_time = self.fine * self.TDC_BIN  # ps
        total_time = coarse_time + fine_time
        
        print(f"\n粗时间范围: {coarse_time.min():.2f} - {coarse_time.max():.2f} ps")
        print(f"细时间范围: {fine_time.min():.2f} - {fine_time.max():.2f} ps")
        print(f"总时间范围: {total_time.min():.2f} - {total_time.max():.2f} ps")
        
        # 如果是扫描模式(141个点)
        if len(self.data) == 141:
            delay = total_time - total_time[0]
            theoretical = np.arange(141) * self.T_PHASE
            error = delay - theoretical
            
            print(f"\n扫描模式分析:")
            print(f"理论延迟范围: 0 - {140*self.T_PHASE:.2f} ps")
            print(f"实际延迟范围: {delay[0]:.2f} - {delay[-1]:.2f} ps")
            print(f"最大误差: {np.max(np.abs(error)):.2f} ps")
            print(f"RMS误差: {np.sqrt(np.mean(error**2)):.2f} ps")
        
        print("="*60 + "\n")
    
    def plot(self, save_path=None):
        """绘制分析图表"""
        if not ANALYSIS_AVAILABLE:
            print("[WARN] matplotlib 不可用,无法绘图")
            return
        
        fig, axes = plt.subplots(2, 2, figsize=(12, 8))
        fig.suptitle('TDC 数据分析', fontsize=14)
        
        # 子图1: 粗计数
        axes[0, 0].plot(self.coarse, 'b.-')
        axes[0, 0].set_xlabel('Sample Index')
        axes[0, 0].set_ylabel('Coarse Count')
        axes[0, 0].set_title('粗计数')
        axes[0, 0].grid(True)
        
        # 子图2: 细计数
        axes[0, 1].plot(self.fine, 'r.-')
        axes[0, 1].set_xlabel('Sample Index')
        axes[0, 1].set_ylabel('Fine Count')
        axes[0, 1].set_title('细计数')
        axes[0, 1].grid(True)
        
        # 子图3: 细计数分布
        axes[1, 0].hist(self.fine, bins=50, edgecolor='black')
        axes[1, 0].set_xlabel('Fine Count')
        axes[1, 0].set_ylabel('Frequency')
        axes[1, 0].set_title('细计数分布')
        axes[1, 0].grid(True)
        
        # 子图4: 如果是扫描模式,显示延迟曲线
        if len(self.data) == 141:
            coarse_time = self.coarse * self.T_CLK * 1000
            fine_time = self.fine * self.TDC_BIN
            total_time = coarse_time + fine_time
            delay = total_time - total_time[0]
            theoretical = np.arange(141) * self.T_PHASE
            
            axes[1, 1].plot(delay, 'b.-', label='实际延迟')
            axes[1, 1].plot(theoretical, 'r--', label='理论延迟')
            axes[1, 1].set_xlabel('Phase Index')
            axes[1, 1].set_ylabel('Delay (ps)')
            axes[1, 1].set_title('延迟 vs 相位')
            axes[1, 1].legend()
            axes[1, 1].grid(True)
        else:
            axes[1, 1].text(0.5, 0.5, '扫描模式下可用', 
                          ha='center', va='center', transform=axes[1, 1].transAxes)
        
        plt.tight_layout()
        
        # 设置保存目录
        save_dir = r"D:\project\vivado_work\TDC\TDC\tdc_scan_results"
        os.makedirs(save_dir, exist_ok=True)
        
        if save_path:
            # 如果save_path不包含路径,则添加save_dir
            if not os.path.dirname(save_path):
                save_path = os.path.join(save_dir, save_path)
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"[INFO] 图表已保存到: {save_path}")
        else:
            # 自动生成文件名并保存
            auto_save_path = os.path.join(save_dir, f"tdc_plot_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png")
            plt.savefig(auto_save_path, dpi=300, bbox_inches='tight')
            print(f"[INFO] 图表已自动保存到: {auto_save_path}")
            plt.show()


def interactive_menu(controller):
    """交互式菜单"""
    while controller.connected:
        print("\n" + "="*60)
        print("TDC 控制菜单")
        print("="*60)
        print("1. 设置 sg_start 延迟")
        print("2. 设置 reset 延迟")
        print("3. TDC 单次测量")
        print("4. TDC 扫描模式 (0-140)")
        print("5. 清空数据缓冲区")
        print("6. 保存数据到文件")
        print("7. 数据分析")
        print("8. 查看接收数据统计")
        print("0. 退出")
        print("="*60)
        
        try:
            choice = input("请选择 (0-8): ").strip()
            
            if choice == '1':
                value = int(input("输入延迟值 (0-31): "))
                controller.set_sg_delay(value)
                
            elif choice == '2':
                value = int(input("输入延迟值 (0-31): "))
                controller.set_reset_delay(value)
                
            elif choice == '3':
                phase = int(input("输入相位值 (0-140): "))
                reset = input("是否复位TDC? (y/n): ").lower() == 'y'
                controller.clear_buffer()
                controller.tdc_single_shot(phase, reset)
                time.sleep(0.5)
                
            elif choice == '4':
                reset = input("是否复位TDC? (y/n): ").lower() == 'y'
                controller.clear_buffer()
                controller.tdc_scan_mode(reset)
                
                # 等待接收141个数据
                if controller.wait_for_data(141, timeout=30.0):
                    print("[INFO] 扫描完成!")
                    
                    # 自动保存
                    filename = controller.save_data()
                    
                    # 询问是否分析
                    if ANALYSIS_AVAILABLE and input("是否分析数据? (y/n): ").lower() == 'y':
                        analyzer = TDCAnalyzer(controller.get_received_data())
                        analyzer.analyze()
                        
                        if input("是否绘制图表? (y/n): ").lower() == 'y':
                            plot_file = filename.replace('.txt', '.png') if filename else None
                            analyzer.plot(plot_file)
                
            elif choice == '5':
                controller.clear_buffer()
                
            elif choice == '6':
                controller.save_data()
                
            elif choice == '7':
                if not ANALYSIS_AVAILABLE:
                    print("[ERROR] 需要安装 numpy 和 matplotlib")
                elif len(controller.get_received_data()) == 0:
                    print("[WARN] 没有数据可分析")
                else:
                    analyzer = TDCAnalyzer(controller.get_received_data())
                    analyzer.analyze()
                    
                    if input("是否绘制图表? (y/n): ").lower() == 'y':
                        analyzer.plot()
                
            elif choice == '8':
                data = controller.get_received_data()
                print(f"\n当前缓冲区数据: {len(data)} 个")
                if len(data) > 0:
                    print(f"最新数据: 0x{data[-1]:08X}")
                
            elif choice == '0':
                break
                
            else:
                print("[WARN] 无效选择")
                
        except ValueError as e:
            print(f"[ERROR] 输入错误: {e}")
        except KeyboardInterrupt:
            print("\n[INFO] 用户中断")
            break


def main():
    """主程序"""
    parser = argparse.ArgumentParser(description='TDC 以太网控制程序')
    parser.add_argument('--host', default='192.168.2.100', help='FPGA IP 地址')
    parser.add_argument('--port', type=int, default=1024, help='TCP 端口')
    parser.add_argument('--interactive', '-i', action='store_true', help='交互式模式')
    
    subparsers = parser.add_subparsers(dest='command', help='命令')
    
    # 子命令定义(保持原有)
    parser_sg = subparsers.add_parser('set-sg-delay', help='设置 sg_start 延迟')
    parser_sg.add_argument('value', type=int, help='延迟值 (0-31)')
    
    parser_rst = subparsers.add_parser('set-reset-delay', help='设置 reset 延迟')
    parser_rst.add_argument('value', type=int, help='延迟值 (0-31)')
    
    parser_single = subparsers.add_parser('single-shot', help='TDC 单次测量')
    parser_single.add_argument('phase', type=int, help='相位值 (0-140)')
    parser_single.add_argument('--reset', action='store_true', help='复位 TDC')
    
    parser_scan = subparsers.add_parser('scan', help='TDC 扫描模式')
    parser_scan.add_argument('--reset', action='store_true', help='复位 TDC')
    parser_scan.add_argument('--analyze', action='store_true', help='分析数据')
    
    args = parser.parse_args()
    
    # 创建控制器
    controller = TDCController(host=args.host, port=args.port)
    
    # 连接到 FPGA
    if not controller.connect():
        return 1
    
    try:
        # 交互式模式
        if args.interactive or not args.command:
            interactive_menu(controller)
        
        # 命令行模式
        elif args.command == 'set-sg-delay':
            controller.set_sg_delay(args.value)
            time.sleep(0.5)
            
        elif args.command == 'set-reset-delay':
            controller.set_reset_delay(args.value)
            time.sleep(0.5)
            
        elif args.command == 'single-shot':
            controller.clear_buffer()
            controller.tdc_single_shot(args.phase, args.reset)
            time.sleep(1.0)
            
        elif args.command == 'scan':
            controller.clear_buffer()
            controller.tdc_scan_mode(args.reset)
            
            # 等待接收141个数据
            if controller.wait_for_data(141, timeout=30.0):
                filename = controller.save_data()
                
                if args.analyze and ANALYSIS_AVAILABLE:
                    analyzer = TDCAnalyzer(controller.get_received_data())
                    analyzer.analyze()
                    
                    plot_file = filename.replace('.txt', '.png') if filename else None
                    analyzer.plot(plot_file)
        
        return 0
        
    except KeyboardInterrupt:
        print("\n[INFO] 用户中断")
        return 130
    finally:
        controller.disconnect()


if __name__ == "__main__":
    sys.exit(main())