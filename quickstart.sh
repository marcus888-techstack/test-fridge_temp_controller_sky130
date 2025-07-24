#!/bin/bash
# ==============================================================================
# quickstart.sh - Quick start guide for the project
# Description: Interactive guide to help users get started
# Author: IC Design Team
# Date: 2024-12-19
# ==============================================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Function to print colored messages
print_msg() {
    echo -e "${1}${2}${NC}"
}

# Function to print header
print_header() {
    clear
    print_msg $BLUE "================================================"
    print_msg $BLUE "   冰箱溫度控制器 IC - 快速開始指南"
    print_msg $BLUE "   Refrigerator Temperature Controller IC"
    print_msg $BLUE "================================================"
    echo
}

# Function to check command
check_cmd() {
    if command -v $1 &> /dev/null; then
        print_msg $GREEN "✓ $1 已安裝"
        return 0
    else
        print_msg $RED "✗ $1 未安裝"
        return 1
    fi
}

# Main menu
main_menu() {
    print_header
    print_msg $CYAN "請選擇操作："
    echo
    echo "1. 檢查環境"
    echo "2. 執行 RTL 模擬"
    echo "3. 執行邏輯合成"
    echo "4. 執行 OpenLane (需要 Docker)"
    echo "5. 查看文檔"
    echo "6. 專案概覽"
    echo "7. 退出"
    echo
    echo -n "請輸入選項 [1-7]: "
    read choice
    
    case $choice in
        1) check_environment ;;
        2) run_simulation ;;
        3) run_synthesis ;;
        4) run_openlane ;;
        5) view_docs ;;
        6) project_overview ;;
        7) exit 0 ;;
        *) 
            print_msg $RED "無效選項！"
            sleep 2
            main_menu
            ;;
    esac
}

# Check environment
check_environment() {
    print_header
    print_msg $YELLOW "檢查開發環境..."
    echo
    
    # Check essential tools
    print_msg $CYAN "必要工具："
    check_cmd git
    check_cmd make
    check_cmd python3
    check_cmd iverilog
    check_cmd gtkwave
    check_cmd yosys
    
    echo
    print_msg $CYAN "可選工具："
    check_cmd verilator
    check_cmd docker
    
    echo
    print_msg $CYAN "環境變數："
    if [ ! -z "$PDK_ROOT" ]; then
        print_msg $GREEN "✓ PDK_ROOT = $PDK_ROOT"
    else
        print_msg $YELLOW "! PDK_ROOT 未設置"
    fi
    
    if [ ! -z "$OPENLANE_ROOT" ]; then
        print_msg $GREEN "✓ OPENLANE_ROOT = $OPENLANE_ROOT"
    else
        print_msg $YELLOW "! OPENLANE_ROOT 未設置"
    fi
    
    echo
    print_msg $BLUE "按 Enter 返回主選單..."
    read
    main_menu
}

# Run simulation
run_simulation() {
    print_header
    print_msg $YELLOW "RTL 模擬選項："
    echo
    echo "1. 執行完整系統測試"
    echo "2. 執行 PID 控制器測試"
    echo "3. 查看波形 (需要先執行測試)"
    echo "4. 返回主選單"
    echo
    echo -n "請選擇 [1-4]: "
    read sim_choice
    
    case $sim_choice in
        1)
            print_msg $CYAN "執行系統測試..."
            cd testbench
            make sim_top
            print_msg $GREEN "測試完成！"
            ;;
        2)
            print_msg $CYAN "執行 PID 測試..."
            cd testbench
            make sim_pid
            print_msg $GREEN "測試完成！"
            ;;
        3)
            cd testbench
            if [ -f "work/temp_ctrl_top_tb.vcd" ]; then
                print_msg $CYAN "開啟波形檢視器..."
                make wave_top &
            else
                print_msg $RED "請先執行測試生成波形檔案！"
            fi
            ;;
        4)
            main_menu
            return
            ;;
    esac
    
    echo
    print_msg $BLUE "按 Enter 繼續..."
    read
    run_simulation
}

# Run synthesis
run_synthesis() {
    print_header
    print_msg $YELLOW "執行邏輯合成..."
    echo
    
    cd synthesis
    if [ -x "./run_synthesis.sh" ]; then
        ./run_synthesis.sh
    else
        print_msg $RED "合成腳本不存在或無執行權限！"
    fi
    
    echo
    print_msg $BLUE "按 Enter 返回主選單..."
    read
    main_menu
}

# Run OpenLane
run_openlane() {
    print_header
    print_msg $YELLOW "OpenLane 流程"
    echo
    
    if [ -z "$OPENLANE_ROOT" ]; then
        print_msg $RED "錯誤：OPENLANE_ROOT 未設置！"
        print_msg $YELLOW "請先安裝 OpenLane 並設置環境變數。"
        echo
        print_msg $BLUE "按 Enter 返回主選單..."
        read
        main_menu
        return
    fi
    
    cd openlane
    if [ -x "./run_openlane.sh" ]; then
        ./run_openlane.sh
    else
        print_msg $RED "OpenLane 腳本不存在或無執行權限！"
    fi
    
    echo
    print_msg $BLUE "按 Enter 返回主選單..."
    read
    main_menu
}

# View documentation
view_docs() {
    print_header
    print_msg $YELLOW "專案文檔："
    echo
    echo "1. 系統規格書"
    echo "2. 架構設計文件"
    echo "3. 完整教學"
    echo "4. README"
    echo "5. 返回主選單"
    echo
    echo -n "請選擇 [1-5]: "
    read doc_choice
    
    case $doc_choice in
        1) less docs/01_specification.md ;;
        2) less docs/02_architecture.md ;;
        3) less docs/03_tutorial.md ;;
        4) less README.md ;;
        5) main_menu; return ;;
    esac
    
    view_docs
}

# Project overview
project_overview() {
    print_header
    print_msg $CYAN "專案概覽"
    echo
    print_msg $YELLOW "專案名稱：" "冰箱溫度控制器 IC"
    print_msg $YELLOW "目標 PDK：" "SKY130 (130nm)"
    print_msg $YELLOW "設計類型：" "數位 IC"
    print_msg $YELLOW "主要功能：" "PID 溫度控制"
    echo
    print_msg $CYAN "技術規格："
    echo "• 工作頻率: 10 MHz"
    echo "• 溫度範圍: -20°C ~ +10°C"
    echo "• 控制精度: ±0.5°C"
    echo "• 目標面積: < 0.5 mm²"
    echo "• 目標功耗: < 5 mW"
    echo
    print_msg $CYAN "主要模組："
    echo "• ADC SPI 介面 (12-bit)"
    echo "• PID 控制器 (16-bit 定點)"
    echo "• PWM 產生器 (10-bit)"
    echo "• 七段顯示控制器"
    echo
    print_msg $CYAN "專案結構："
    tree -L 2 2>/dev/null || ls -la
    echo
    print_msg $BLUE "按 Enter 返回主選單..."
    read
    main_menu
}

# Start the script
print_header
print_msg $GREEN "歡迎使用冰箱溫度控制器 IC 專案！"
print_msg $YELLOW "本指南將協助您快速開始專案開發。"
echo
print_msg $BLUE "按 Enter 開始..."
read

# Main loop
while true; do
    main_menu
done