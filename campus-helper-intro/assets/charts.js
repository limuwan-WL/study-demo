(function () {
  var style = getComputedStyle(document.documentElement);
  var accent = style.getPropertyValue('--accent').trim();
  var accent2 = style.getPropertyValue('--accent2').trim();
  var ink = style.getPropertyValue('--ink').trim();
  var muted = style.getPropertyValue('--muted').trim();
  var rule = style.getPropertyValue('--rule').trim();
  var bg2 = style.getPropertyValue('--bg2').trim();
  var fontStack = "Outfit, 'PingFang SC', 'Microsoft YaHei', sans-serif";

  /* ===== Mermaid ===== */
  if (window.mermaid) {
    mermaid.initialize({
      startOnLoad: true,
      theme: 'base',
      securityLevel: 'loose',
      themeVariables: {
        fontFamily: fontStack,
        fontSize: '14px',
        primaryColor: '#eaf1fe',
        primaryTextColor: ink,
        primaryBorderColor: accent,
        lineColor: '#8fa6c9',
        secondaryColor: '#e6f7f4',
        tertiaryColor: bg2,
        mainBkg: '#eaf1fe',
        nodeBorder: accent,
        clusterBkg: '#f5f8fd',
        clusterBorder: rule,
        edgeLabelBackground: '#ffffff',
        textColor: ink
      },
      flowchart: { curve: 'basis', htmlLabels: true, padding: 14, nodeSpacing: 42, rankSpacing: 46 }
    });
  }

  /* ===== 通用横向条形图配置 ===== */
  function barOption(categories, values, color) {
    return {
      animation: false,
      grid: { left: 8, right: 48, top: 8, bottom: 8, containLabel: true },
      tooltip: {
        trigger: 'axis',
        axisPointer: { type: 'shadow' },
        appendToBody: true,
        backgroundColor: '#ffffff',
        borderColor: rule,
        textStyle: { color: ink, fontFamily: fontStack }
      },
      xAxis: {
        type: 'value',
        splitLine: { lineStyle: { color: rule } },
        axisLabel: { color: muted, fontFamily: fontStack },
        axisLine: { show: false }
      },
      yAxis: {
        type: 'category',
        data: categories,
        inverse: true,
        axisTick: { show: false },
        axisLine: { show: false },
        axisLabel: { color: ink, fontFamily: fontStack, fontSize: 13 }
      },
      series: [{
        type: 'bar',
        data: values,
        barWidth: 18,
        itemStyle: { color: color, borderRadius: [0, 9, 9, 0] },
        label: {
          show: true,
          position: 'right',
          color: muted,
          fontFamily: fontStack,
          fontSize: 12,
          formatter: '{c}'
        }
      }]
    };
  }

  /* ===== 图表 1：代码文件构成 ===== */
  var elFiles = document.getElementById('chart-files');
  if (elFiles && window.echarts) {
    var chartFiles = echarts.init(elFiles, null, { renderer: 'svg' });
    chartFiles.setOption(barOption(
      ['页面 pages', '数据模型 model', '工具类 utils', '公共组件 components', '入口 / 备份'],
      [80, 26, 14, 3, 2],
      accent
    ));
    window.addEventListener('resize', function () { chartFiles.resize(); });
  }

  /* ===== 图表 2：路由页面按业务域分布 ===== */
  var elPages = document.getElementById('chart-pages');
  if (elPages && window.echarts) {
    var chartPages = echarts.init(elPages, null, { renderer: 'svg' });
    chartPages.setOption(barOption(
      ['course 课程', 'subjects 学科', 'study 学习工具', 'common 通用', 'social 社区', 'Index 主框架'],
      [20, 20, 15, 12, 4, 1],
      accent2
    ));
    window.addEventListener('resize', function () { chartPages.resize(); });
  }
})();
