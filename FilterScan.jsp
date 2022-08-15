<%@page import="java.io.File"%>
<%@page import="java.io.FileOutputStream"%>
<%@page import="com.sun.org.apache.bcel.internal.classfile.JavaClass"%>
<%@page import="com.sun.org.apache.bcel.internal.Repository"%>
<%@page import="org.apache.tomcat.util.descriptor.web.FilterDef"%>
<%@page import="java.util.Map.Entry"%>
<%@page import="java.util.LinkedHashMap"%>
<%@page import="java.util.*"%>
<%@page import="org.apache.tomcat.util.descriptor.web.FilterMap"%>
<%@ page import="java.lang.reflect.Field"%>
<%@ page import="org.apache.catalina.core.*" %>
<%--
  Tomcat中Filter扫描,列表从上到下是filter将被执行的顺序
--%>
<%@ page contentType="text/html;charset=UTF-8" language="java"%>
<%!//自定义FilterBean
class FilterBean {
	// filter名
	private String filterName;
	// filter类
	private String filterClass;
	// 过滤的接口
	private List<String> urlMapping;
	
	public FilterBean(String filterName,List<String> urlMapping,String filterClass){
		this.filterName = filterName;
		this.urlMapping = urlMapping;
		this.filterClass = filterClass;
	}
	
	public FilterBean(String filterName,List<String> urlMapping){
		this.filterName = filterName;
		this.urlMapping = urlMapping;
	}
	
	public String getFilterName() {
		return filterName;
	}
	public void setFilterName(String filterName) {
		this.filterName = filterName;
	}
	public String getFilterClass() {
		return filterClass;
	}
	public void setFilterClass(String filterClass) {
		this.filterClass = filterClass;
	}
	public List<String> getUrlMapping() {
		return urlMapping;
	}
	public void setUrlMapping(List<String> urlMapping) {
		this.urlMapping = urlMapping;
	}
}

//获得StandardContext
public StandardContext getStandardContext(HttpServletRequest request) throws Exception{
	//获取ApplicationContext
	ServletContext servletContext = request.getSession().getServletContext();
	Field appctx = servletContext.getClass().getDeclaredField("context");
	appctx.setAccessible(true);
	ApplicationContext applicationContext = (ApplicationContext) appctx.get(servletContext);

	//获取StandardContext
	Field context = applicationContext.getClass().getDeclaredField("context");
	context.setAccessible(true);
	return (StandardContext) context.get(applicationContext);
}
//获取当前路径
public String getPath(HttpServletRequest req,String filename) {
	String path = req.getSession().getServletContext().getRealPath(filename);
	return path.substring(0, path.lastIndexOf(File.separator));
}
//dump class
public void dumpClass(String className){
	try {
		JavaClass javaClass = Repository.lookupClass(Class.forName(className));
		String simpleClassName = className.substring(className.lastIndexOf(".") + 1);
		FileOutputStream fos = new FileOutputStream(path + File.separator + simpleClassName + ".dump");
		javaClass.dump(fos);
	} catch(Exception e) {
		
	}
}
//获得所有注册的filter
public Set<? extends Entry<String, ? extends FilterRegistration>> getFilterRegistrations(HttpServletRequest request){
	Map<String, ? extends FilterRegistration> filters = request.getSession().getServletContext().getFilterRegistrations();
	return filters.entrySet();
}
//获得Filter Entry
public Set<Entry<String, FilterBean>> getEntry(){
	//Filter列表
	LinkedHashMap<String, FilterBean> filterMap = new LinkedHashMap<>();
	//获得所有的Filter及映射
	for (FilterMap filter : filterMaps) {
		String name = filter.getFilterName();
		String[] urlMappings = filter.getURLPatterns();
		List<String> url = new ArrayList<>();
		//E9存在多个相同的filter对应不同的url的情况
		if (filterMap.containsKey(name)) {
			FilterBean filterBean = filterMap.get(name);
			url = filterBean.getUrlMapping();
			for (String urlMapping : urlMappings) {
				url.add(urlMapping);
			}
			filterBean.setUrlMapping(url);
			filterMap.replace(name,filterBean);
		} else{
			for (String urlMapping : urlMappings) {
				url.add(urlMapping);
			}
			filterMap.put(name, new FilterBean(name, url));
		}
	}
	//遍历filters，得到相关信息
	for (Entry<String, ? extends FilterRegistration> entry:filters) {
		ApplicationFilterRegistration f = (ApplicationFilterRegistration) entry.getValue();
		String filterName = f.getName();
		String filterClass = f.getClassName();
		FilterBean filterBean = filterMap.get(filterName);
		if (filterBean != null) {
			filterBean.setFilterClass(filterClass);
			filterMap.replace(filterName, filterBean);
		} else {

		}
	}
	return filterMap.entrySet();
}
//删除指定的Filter
public void delFiler(String delFilterName){
	//删除指定的filterDef
	FilterDef delFilter = standardContext.findFilterDef(delFilterName);
	if (delFilter != null) {
		standardContext.removeFilterDef(delFilter);
	}
		
	//删除指定的filter映射
	for (FilterMap filter : filterMaps) {
		String name = filter.getFilterName();
		if (name.equals(delFilterName)) {
			standardContext.removeFilterMap(filter);
			continue;
		}
	}
}

public void delFilterUrlMapping(String filterName,String urlMapping){
	//删除指定的filter映射
	for (FilterMap filter : filterMaps) {
		String name = filter.getFilterName();
		String[] urlPatterns = filter.getURLPatterns();
		for (String url:urlPatterns) {
			if (name.equals(filterName) && urlMapping.equals(url)) {
				standardContext.removeFilterMap(filter);
				continue;
			}
		}
	}
}

StandardContext standardContext;

FilterMap[] filterMaps;

Set<? extends Entry<String, ? extends FilterRegistration>> filters;

String path = null;

%>

<%
//获取待删除的filter名，并判断是否执行删除操作
String delFilterName = request.getParameter("delFilterName");
String className = request.getParameter("className");
String delUrlMapping = request.getParameter("delUrlMapping");
boolean runDelUrlMapping = delUrlMapping != null && !"".equals(delUrlMapping);
boolean runDelFilter = !runDelUrlMapping && delFilterName != null && !"".equals(delFilterName);
boolean runDump = className != null && !"".equals(className);
path = getPath(request, "FilterScan.jsp").replaceAll("\\\\","\\\\\\\\");
//获得StandardContext
standardContext = getStandardContext(request);

//拿到所有的FilterMap,将FilterMap中对应的filter数据添加到filterMap中
filterMaps = standardContext.findFilterMaps();

//获得所有filter
filters = getFilterRegistrations(request);

if (runDelUrlMapping){
	delFilterUrlMapping(delFilterName, delUrlMapping);
	response.sendRedirect(request.getRequestURL().toString());
	return;
}

//执行删除操作
if(runDelFilter) {
	delFiler(delFilterName);
	//filterChain中的FilterConfig无法被删除，导致删除后仍能查询到Filter；使用转发刷新页面，使删除操作生效，同时会丢弃携带的相关参数
	response.sendRedirect(request.getRequestURL().toString());
	return;
}

//执行dump操作
if(runDump) {
	dumpClass(className);
}

//获得所有Filter
Set<Entry<String, FilterBean>> entrySet = getEntry();

%>

<html lang="en">
<head>
<meta charset="UTF-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Tomcat-Filter列表</title>
<style>
.body {
	width: 100%;
	margin: 0 auto;
	font-family: "consolas";
	background-color: #DCDCDC;
}

.content{
	width: 100%;
	margin-top: 50px;
}

.title {
	text-align: center;
}

.table {
	width: 80%;
	margin:0 auto;
	border-radius: 4px;
	padding: 5px;
}
.table-header{
	text-align: center;
}
.table-header th{
	border:2px solid #000000;
	border-radius: 1px;
}
.table-safe td{
	border:2px solid #000000;
	border-radius: 1px;
}
.table-safe{
	text-align: center;
}
</style>
</head>
<body class="body">
	<script type="text/javascript">
		var message = "慎重执行删除操作！！！删除操作不可逆，如果删除了正常的内容后想恢复，则需要重启OA。"
		alert(message)
	</script>
	<div class="content">
		<div class="">
			<div class="title">
				<h1>Tomcat-Filter列表</h1>
			</div>
			<table class="table">
				<tr class="table-header">
					<th>Filter名称</th>
					<th>Filter实际的类</th>
					<th>Filter过滤的接口</th>
					<th>操作</th>
				</tr>
				<%
				for (Entry<String, FilterBean> entry : entrySet) {
					FilterBean filter = entry.getValue();
					List<String> urlMappings = filter.getUrlMapping();
				%>
				<tr class="table-safe">
					<td><%=filter.getFilterName() %></td>
					<td style="text-align: left;font-family: 'consolas';"><%=filter.getFilterClass() %></td>
					<td style="text-align: left">
						<%
							for(int index = 0;index < urlMappings.size();index ++) {
								String url = urlMappings.get(index);
						%>
						<%=url %>&nbsp;&nbsp;<button class="button" onclick="delUrlMapping('<%=filter.getFilterName()%>','<%=url%>')">delete mapping</button><%=index == urlMappings.size() - 1 ? "":"<br/><br/>" %>
						<%
							}
						%>
					</td>
					<td><button class="button" onclick="delFilter('<%=filter.getFilterName()%>')">delete</button>
					<button class="button" onclick="dump('<%=filter.getFilterClass()%>')">dump</button>
				</tr>
				<%
				}
				%>
			</table>
			
			<form id="filterForm" action="" method="get" style="display: none;">
				<input id="delFilterName" name="delFilterName">
				<input id="className" name="className">
				<input id="delUrlMapping" name="delUrlMapping">
			</form>
		</div>
	</div>
</body>
<script type="text/javascript">
function delFilter(filterName){
	var msg = "确认删除" + filterName + "吗?"
	if (confirm(msg)) {
		document.getElementById("delFilterName").value = filterName
		document.getElementById("className").value = null
		document.getElementById("delUrlMapping").value = null
		document.getElementById("filterForm").submit()
	} 
}
function delUrlMapping(filterName,urlMapping){
	var msg = "确认删除" + filterName + "对" + urlMapping + "接口的拦截吗?"
	alert(msg)
	document.getElementById("delFilterName").value = filterName
	document.getElementById("className").value = null
	document.getElementById("delUrlMapping").value = urlMapping
	document.getElementById("filterForm").submit()
}
function dump(filterName){
	var msg = "dump出的文件存放在<%=path%>目录中"
	alert(msg)
	document.getElementById("delFilterName").value = null
	document.getElementById("className").value = filterName
	document.getElementById("delUrlMapping").value = null
	document.getElementById("filterForm").submit()
}
</script>
</html>