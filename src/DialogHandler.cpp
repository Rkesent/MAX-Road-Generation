/**
 * DialogHandler.cpp - 对话框处理函数实现
 * 
 * 实现用户界面的初始化和交互逻辑
 */

#include "RoadLineGenerator.h"

// 标线类型枚举
enum LineType {
    LINE_TYPE_SOLID = 0,    // 实线
    LINE_TYPE_DASHED,       // 虚线
    LINE_TYPE_CROSSWALK,    // 斑马线
    LINE_TYPE_GUIDELINE     // 导流线
};

// 全局变量
static int g_lineType = LINE_TYPE_SOLID;
static float g_lineWidth = 0.15f;
static float g_lineSpacing = 0.3f;
static int g_iterations = 100;
static float g_threshold = 0.1f;
static bool g_preview = false;
static Color g_lineColor(1.0f, 1.0f, 1.0f);

// 对话框处理函数
INT_PTR CALLBACK RoadLineGeneratorDlgProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    RoadLineGenerator* roadLineGen = nullptr;
    
    if (msg == WM_INITDIALOG) {
        roadLineGen = (RoadLineGenerator*)lParam;
        SetWindowLongPtr(hWnd, GWLP_USERDATA, lParam);
        
        // 初始化标线类型下拉框
        HWND hCombo = GetDlgItem(hWnd, IDC_CMB_LINE_TYPE);
        SendMessage(hCombo, CB_ADDSTRING, 0, (LPARAM)_T("实线"));
        SendMessage(hCombo, CB_ADDSTRING, 0, (LPARAM)_T("虚线"));
        SendMessage(hCombo, CB_ADDSTRING, 0, (LPARAM)_T("斑马线"));
        SendMessage(hCombo, CB_ADDSTRING, 0, (LPARAM)_T("导流线"));
        SendMessage(hCombo, CB_SETCURSEL, g_lineType, 0);
        
        // 初始化宽度编辑框
        SetDlgItemText(hWnd, IDC_EDIT_WIDTH, _T("0.15"));
        
        // 初始化间距编辑框
        SetDlgItemText(hWnd, IDC_EDIT_SPACING, _T("0.3"));
        
        // 初始化RANSAC参数
        SetDlgItemText(hWnd, IDC_EDIT_ITERATIONS, _T("100"));
        SetDlgItemText(hWnd, IDC_EDIT_THRESHOLD, _T("0.1"));
        
        // 初始化预览复选框
        CheckDlgButton(hWnd, IDC_CHK_PREVIEW, g_preview ? BST_CHECKED : BST_UNCHECKED);
        
        return TRUE;
    } else {
        roadLineGen = (RoadLineGenerator*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
    }
    
    if (!roadLineGen && msg != WM_INITDIALOG) return FALSE;
    
    switch (msg) {
        case WM_COMMAND:
            switch (LOWORD(wParam)) {
                case IDC_BTN_GENERATE:
                    // 获取参数
                    g_lineType = (int)SendDlgItemMessage(hWnd, IDC_CMB_LINE_TYPE, CB_GETCURSEL, 0, 0);
                    
                    TCHAR buffer[64];
                    GetDlgItemText(hWnd, IDC_EDIT_WIDTH, buffer, 64);
                    g_lineWidth = (float)_tstof(buffer);
                    
                    GetDlgItemText(hWnd, IDC_EDIT_SPACING, buffer, 64);
                    g_lineSpacing = (float)_tstof(buffer);
                    
                    GetDlgItemText(hWnd, IDC_EDIT_ITERATIONS, buffer, 64);
                    g_iterations = _tstoi(buffer);
                    
                    GetDlgItemText(hWnd, IDC_EDIT_THRESHOLD, buffer, 64);
                    g_threshold = (float)_tstof(buffer);
                    
                    g_preview = (IsDlgButtonChecked(hWnd, IDC_CHK_PREVIEW) == BST_CHECKED);
                    
                    // 生成标线
                    roadLineGen->GenerateRoadLines(g_lineType, g_lineWidth, g_lineSpacing, g_iterations, g_threshold, g_preview, g_lineColor);
                    return TRUE;
                    
                case IDC_CMB_LINE_TYPE:
                    if (HIWORD(wParam) == CBN_SELCHANGE) {
                        // 标线类型改变，更新UI
                        g_lineType = (int)SendDlgItemMessage(hWnd, IDC_CMB_LINE_TYPE, CB_GETCURSEL, 0, 0);
                        
                        // 根据标线类型启用/禁用相关控件
                        BOOL enableSpacing = (g_lineType == LINE_TYPE_DASHED || g_lineType == LINE_TYPE_CROSSWALK);
                        EnableWindow(GetDlgItem(hWnd, IDC_EDIT_SPACING), enableSpacing);
                        
                        // 如果启用了预览，则实时更新
                        if (g_preview) {
                            // 获取其他参数
                            TCHAR buffer[64];
                            GetDlgItemText(hWnd, IDC_EDIT_WIDTH, buffer, 64);
                            g_lineWidth = (float)_tstof(buffer);
                            
                            GetDlgItemText(hWnd, IDC_EDIT_SPACING, buffer, 64);
                            g_lineSpacing = (float)_tstof(buffer);
                            
                            GetDlgItemText(hWnd, IDC_EDIT_ITERATIONS, buffer, 64);
                            g_iterations = _tstoi(buffer);
                            
                            GetDlgItemText(hWnd, IDC_EDIT_THRESHOLD, buffer, 64);
                            g_threshold = (float)_tstof(buffer);
                            
                            // 更新预览
                            roadLineGen->GenerateRoadLines(g_lineType, g_lineWidth, g_lineSpacing, g_iterations, g_threshold, true, g_lineColor);
                        }
                        return TRUE;
                    }
                    break;
                    
                case IDC_CHK_PREVIEW:
                    g_preview = (IsDlgButtonChecked(hWnd, IDC_CHK_PREVIEW) == BST_CHECKED);
                    return TRUE;
                    
                case IDC_CLR_LINE:
                    // 颜色选择器
                    if (HIWORD(wParam) == BN_CLICKED) {
                        // 打开颜色对话框
                        COLORREF initColor = RGB(g_lineColor.r * 255, g_lineColor.g * 255, g_lineColor.b * 255);
                        COLORREF newColor;
                        
                        CHOOSECOLOR cc;
                        ZeroMemory(&cc, sizeof(cc));
                        cc.lStructSize = sizeof(cc);
                        cc.hwndOwner = hWnd;
                        cc.lpCustColors = (LPDWORD)malloc(16 * sizeof(DWORD));
                        cc.rgbResult = initColor;
                        cc.Flags = CC_FULLOPEN | CC_RGBINIT;
                        
                        if (ChooseColor(&cc)) {
                            newColor = cc.rgbResult;
                            g_lineColor.r = GetRValue(newColor) / 255.0f;
                            g_lineColor.g = GetGValue(newColor) / 255.0f;
                            g_lineColor.b = GetBValue(newColor) / 255.0f;
                            
                            // 如果启用了预览，则实时更新
                            if (g_preview) {
                                // 获取其他参数
                                TCHAR buffer[64];
                                GetDlgItemText(hWnd, IDC_EDIT_WIDTH, buffer, 64);
                                g_lineWidth = (float)_tstof(buffer);
                                
                                GetDlgItemText(hWnd, IDC_EDIT_SPACING, buffer, 64);
                                g_lineSpacing = (float)_tstof(buffer);
                                
                                GetDlgItemText(hWnd, IDC_EDIT_ITERATIONS, buffer, 64);
                                g_iterations = _tstoi(buffer);
                                
                                GetDlgItemText(hWnd, IDC_EDIT_THRESHOLD, buffer, 64);
                                g_threshold = (float)_tstof(buffer);
                                
                                // 更新预览
                                roadLineGen->GenerateRoadLines(g_lineType, g_lineWidth, g_lineSpacing, g_iterations, g_threshold, true, g_lineColor);
                            }
                        }
                        
                        free(cc.lpCustColors);
                        return TRUE;
                    }
                    break;
            }
            break;
            
        case WM_DRAWITEM:
            if (wParam == IDC_CLR_LINE) {
                LPDRAWITEMSTRUCT lpDIS = (LPDRAWITEMSTRUCT)lParam;
                HBRUSH hBrush = CreateSolidBrush(RGB(g_lineColor.r * 255, g_lineColor.g * 255, g_lineColor.b * 255));
                FillRect(lpDIS->hDC, &lpDIS->rcItem, hBrush);
                FrameRect(lpDIS->hDC, &lpDIS->rcItem, (HBRUSH)GetStockObject(BLACK_BRUSH));
                DeleteObject(hBrush);
                return TRUE;
            }
            break;
    }
    
    return FALSE;
}