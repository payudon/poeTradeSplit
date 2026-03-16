#Requires AutoHotkey v2.0
#SingleInstance Force

; --- 界面初始化 ---
MyGui := Gui("+Resize", "PoE 贸易搜索 URL 拆分工具")
MyGui.SetFont("s10", "Microsoft YaHei")

; 第一行：配置栏
MyGui.Add("Text", "x10 y15", "每份最大拆分个数:")
EditMax := MyGui.Add("Edit", "x130 y12 w60", "40")
CheckCN := MyGui.Add("Checkbox", "x210 y15 Checked", "转换为国服域名 (game.qq.com)")

; 第二行：输入栏
MyGui.Add("Text", "x10 y55", "源搜索 URL:")
EditSource := MyGui.Add("Edit", "x10 y80 w760 r3", "")

; 按钮层
BtnSplit := MyGui.Add("Button", "x10 y150 w100 h30 Default", "开始拆分")
BtnSplit.OnEvent("Click", SplitURL)

; 第三行到第N行：结果显示区域
MyGui.Add("Text", "x10 y190", "拆分结果（双击行可直接打开）:")
ResultPanel := MyGui.Add("ListView", "x10 y215 w760 h350 +Grid", ["序号", "新 URL", "操作"])
ResultPanel.OnEvent("Click", HandleListClick)
ResultPanel.ModifyCol(1, 50)
ResultPanel.ModifyCol(2, 600)
ResultPanel.ModifyCol(3, 80)

; --- 焦点处理 ---
; 在显示界面前，将光标默认定位到地址输入栏
EditSource.Focus()

MyGui.Show("w780 h580")

; --- 逻辑处理函数 ---

SplitURL(*) {
    sourceUrl := EditSource.Value
    
    if (sourceUrl == "") {
        MsgBox("请输入源 URL！")
        return
    }

    try {
        ; 1. 解析 URL 结构
        if (!RegExMatch(sourceUrl, "(.+\?q=)(.+)", &match)) {
            throw Error("无效的 URL 格式，未找到查询参数 '?q='")
        }
        
        baseUrl := match[1]
        jsonStr := match[2]
        
        ; 简单的 URL 解码
        decodeMap := Map(
            "%7B", "{", "%7D", "}", "%5B", "[", "%5D", "]", 
            "%22", '"', "%2C", ",", "%3A", ":", "%5F", "_"
        )
        for enc, dec in decodeMap {
            jsonStr := StrReplace(jsonStr, enc, dec)
        }

        ; 2. 提取所有的 filter 成员
        filters := []
        pos := 1
        while (RegExMatch(jsonStr, '(\{"id":"[^"]+","value":\{"max":[^,]+,"min":[^}]+\}\})', &fMatch, pos)) {
            filters.Push(fMatch[1])
            pos := fMatch.Pos + fMatch.Len
        }

        if (filters.Length == 0) {
            MsgBox("未在 URL 中找到有效的 filters 过滤项。")
            return
        }

        ; 3. 处理域名转换
        if (CheckCN.Value) {
            baseUrl := StrReplace(baseUrl, "www.pathofexile.com", "poe.game.qq.com")
        }

        ; 4. 执行拆分
        maxCount := Integer(EditMax.Value)
        ResultPanel.Delete()
        
        totalBatches := ceil(filters.Length / maxCount)
        
        loop totalBatches {
            batchIdx := A_Index
            startIdx := (batchIdx - 1) * maxCount + 1
            
            currentBatch := []
            loop Min(maxCount, filters.Length - startIdx + 1) {
                currentBatch.Push(filters[startIdx + A_Index - 1])
            }
            
            filterJoin := ""
            for i, val in currentBatch {
                filterJoin .= val . (i == currentBatch.Length ? "" : ",")
            }
            
            newJson := RegExReplace(jsonStr, '("filters":\[)(.*?)(\])', "$1" . filterJoin . "$3")
            finalUrl := baseUrl . EncodeURI(newJson)
            ResultPanel.Add(, batchIdx, finalUrl, "点击打开")
        }

    } catch Error as e {
        MsgBox("解析错误: " . e.Message)
    }
}

HandleListClick(LV, RowNum) {
    if (RowNum == 0) {
        return
    }
    
    targetUrl := LV.GetText(RowNum, 2)
    if (targetUrl != "") {
        Run(targetUrl)
    }
}

EncodeURI(str) {
    str := StrReplace(str, "{", "%7B")
    str := StrReplace(str, "}", "%7D")
    str := StrReplace(str, "[", "%5B")
    str := StrReplace(str, "]", "%5D")
    str := StrReplace(str, '"', "%22")
    str := StrReplace(str, ",", "%2C")
    str := StrReplace(str, ":", "%3A")
    str := StrReplace(str, "_", "%5F")
    return str
}