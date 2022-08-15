<%@page import="org.apache.catalina.core.ApplicationContext"%>
<%@page import="java.io.FileOutputStream"%>
<%@page import="java.io.File"%>
<%@page import="com.sun.org.apache.bcel.internal.Repository"%>
<%@page import="com.sun.org.apache.bcel.internal.classfile.JavaClass"%>
<%@page import="java.util.Map.Entry"%>
<%@ page import="java.lang.reflect.Field" %>
<%@ page import="org.apache.catalina.Container" %>
<%@ page import="java.util.*" %>
<%@ page import="org.apache.catalina.Wrapper" %>
<%@ page import="org.apache.catalina.core.StandardContext" %>
<%--
  Tomcat中Servlet扫描,servlet从standardcontext中取出，其他容器中无法存入servlet
  
  User: gaoshang
  Date: 2022/2/21
--%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%!//自定义ServletBean
class ServletBean {
	// servlet名
	private String servletName;
	// servlet类
	private String servletClass;
	// 映射的地址
	private List<String> urlMapping;
	// 是否初始化执行
	private Boolean loadOnStartup;
	
	public ServletBean(String servletName,String servletClass,List<String> urlMapping,Boolean loadOnStartup){
		this.servletName = servletName;
		this.servletClass = servletClass;
		this.urlMapping = urlMapping;
		this.loadOnStartup = loadOnStartup;
	}
	
	public String getServletName() {
		return servletName;
	}
	public void setServletName(String servletName) {
		this.servletName = servletName;
	}
	public String getServletClass() {
		return servletClass;
	}
	public void setServletClass(String servletClass) {
		this.servletClass = servletClass;
	}
	public List<String> getUrlMapping() {
		return urlMapping;
	}
	public void setUrlMapping(List<String> urlMapping) {
		this.urlMapping = urlMapping;
	}
	public Boolean getLoadOnStartup() {
		return loadOnStartup;
	}
	public void setLoadOnStartup(Boolean loadOnStartup) {
		this.loadOnStartup = loadOnStartup;
	}
	
}
//获得StandardContext
public StandardContext getStandardContext(HttpServletRequest request) throws Exception{
	ServletContext servletContext = request.getSession().getServletContext();
	Field appctx = servletContext.getClass().getDeclaredField("context");
	appctx.setAccessible(true);
	ApplicationContext applicationContext = (ApplicationContext) appctx.get(servletContext);

	//获取StandardContext
	Field context = applicationContext.getClass().getDeclaredField("context");
	context.setAccessible(true);
	return (StandardContext) context.get(applicationContext);
}
//获取servlet集合
public Set<Map.Entry<String, Container>> getContainerSet(StandardContext context) throws Exception{
	//拿到所有servlet children
	Field children = context.getClass().getSuperclass().getDeclaredField("children");
	children.setAccessible(true);
	HashMap<String, Container> childrenMap = (HashMap<String, Container>) children.get(context);
	return childrenMap.entrySet();
}
//遍历封装children
public Set<Entry<String, ServletBean>> getChildrenSet(Set<Map.Entry<String, Container>> entries,StandardContext context) throws Exception{
	LinkedHashMap<String, ServletBean> servletMap = new LinkedHashMap<>();
	//遍历集合
	for (Map.Entry<String, Container> entry : entries) {
		Wrapper value = (Wrapper) entry.getValue();
		String servletName = value.getName();
		
		String servletClass = value.getServletClass();
		String[] mappings = value.findMappings();
		Boolean loadOnStartup = value.getLoadOnStartup() >= 1;
		
		List<String> urlMapping = new ArrayList<>();
		for (String mapping : mappings) {
			urlMapping.add(mapping);
		}
		servletMap.put(servletName, new ServletBean(servletName, servletClass, urlMapping, loadOnStartup));
	}
	return servletMap.entrySet();
}
//删除servlet
public boolean delChild(Set<Map.Entry<String, Container>> entries,StandardContext context,String delServletName) {
	for (Map.Entry<String, Container> entry : entries) {
		Wrapper value = (Wrapper) entry.getValue();
		String servletName = value.getName();
		if (servletName.equals(delServletName)) {
			context.removeChild(value);
			return true;
		}
	}
	return false;
}
//删除映射
public boolean delUrlMapping(StandardContext context,String urlMapping) {
	context.removeServletMapping(urlMapping);
	return true;
}
//获取当前路径
public String getPath(HttpServletRequest req,String filename) {
	String path = req.getSession().getServletContext().getRealPath(filename);
	return path.substring(0, path.lastIndexOf(File.separator));
}
//dump class
public void dumpClass(String className,HttpServletRequest req){
	try {
		JavaClass javaClass = Repository.lookupClass(Class.forName(className));
		String simpleClassName = className.substring(className.lastIndexOf(".") + 1, className.length());
		FileOutputStream fos = new FileOutputStream(path + File.separator + simpleClassName + ".dump");
		javaClass.dump(fos);
	} catch(NullPointerException ne) {
		req.setAttribute("errmsg", "dump class 失败");
	} catch(ClassNotFoundException cfe) {
		req.setAttribute("errmsg", "dump class 失败");
	} catch(Exception e) {
		
	}
}

String path = "";
%>

<%
//获取待删除的servlet名，并判断是否执行删除操作
String servletValue = request.getParameter("servletValue");
String urlMapping = request.getParameter("urlMapping");
String className = request.getParameter("className");
//是否执行dump操作
boolean runDump = className != null && !"".equals(className);
//是否执行删除servlet操作
boolean runDelServlet = Boolean.valueOf(request.getParameter("runDelServlet"));
path = getPath(request,"ServletScan.jsp").replaceAll("\\\\", "\\\\\\\\");
//是否执行删除url映射操作
boolean runDelUrlMapping = Boolean.valueOf(request.getParameter("runDelUrlMapping"));
//获取StandardContext
StandardContext context = getStandardContext(request);
Set<Map.Entry<String, Container>> cointainerSet = getContainerSet(context);
//dump class
if(runDump) {
	dumpClass(className,request);
}
//删除servlet
if(runDelServlet) {
	delChild(cointainerSet,context,servletValue);
}
//删除servlet映射
if(runDelUrlMapping) {
	delUrlMapping(context,urlMapping);
}
//获取Servlet Children
Set<Map.Entry<String, ServletBean>> entrySet = getChildrenSet(cointainerSet, context);
%>

<html lang="en">
<head>
<meta charset="UTF-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Tomcat-Servlet列表</title>
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
.button{
	font-size: medium;
	text-decoration: underline;
}
.button:hover {
	color: #6495ED;
	cursor: pointer;
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
				<h1>Tomcat-Servlet列表</h1>
			</div>
			<table  class="table">
				<tr class="table-header">
					<th>Servlet实际的类</th>
					<th>Servlet映射的接口</th>
					<th>是否在容器启动时运行</th>
					<th>操作</th>
				</tr>
				<%
				for (Entry<String, ServletBean> entry:entrySet) {
					ServletBean servlet = entry.getValue();
					List<String> urlMappings = servlet.getUrlMapping();
				%>
				<tr class="table-safe" rowspan="<%=urlMappings.size()%>">
					<td style="text-align: left;"><%=servlet.getServletClass() %></td>
					<td rowspan="1">
					<%
					for(int index = 0;index < urlMappings.size();index ++) {
						String url = urlMappings.get(index);
					%>
					<%=url %>&nbsp;&nbsp;<button class="button" onclick="delUrlMapping('<%=url%>')">delete mapping</button><%=index == urlMappings.size() - 1 ? "":"<br/><br/>" %>
					<%
					}
					%>
					</td>
					
					<td style="color: <%=servlet.getLoadOnStartup() ? "red":"green"%>"><%=servlet.getLoadOnStartup()? "是" : "否"%></td>
					<td><button class="button" onclick="delServlet('<%=servlet.getServletName()%>')">delete</button>
					<button class="button" onclick="dump('<%=servlet.getServletClass()%>')">dump</button></td>
				</tr>
				<%
				}
				%>
			</table>
			
			<form id="delServletForm" action="" method="get" style="display: none;">
				<input id="servletValue" name="servletValue">
				<input id="urlMapping" name="urlMapping">
				<input id="runDelServlet" name = "runDelServlet" value="false">
				<input id="runDelUrlMapping" name = "runDelUrlMapping" value="false">
				<input id="className" name = "className">
			</form>
		</div>
	</div>
</body>
<script type="text/javascript">
function delServlet(servletName){
	var msg = "确认删除 " + servletName + " 吗?"
	if (confirm(msg)) {
		document.getElementById("servletValue").value = servletName
		document.getElementById("urlMapping").value = null
		document.getElementById("runDelServlet").value = true
		document.getElementById("runDelUrlMapping").value = false
		document.getElementById("className").value = null
		document.getElementById("delServletForm").submit()
	} 
}
function delUrlMapping(urlMapping){
	var msg = "确认删除 " + urlMapping + " 接口吗?"
	if (confirm(msg)) {
		document.getElementById("servletValue").value = null
		document.getElementById("urlMapping").value = urlMapping
		document.getElementById("runDelServlet").value = false
		document.getElementById("runDelUrlMapping").value = true
		document.getElementById("className").value = null
		document.getElementById("delServletForm").submit()
	}
}
function dump(className){
	var msg = "dump出的文件存放在<%=path%>目录中"
	alert(msg)
	document.getElementById("servletValue").value = null
	document.getElementById("urlMapping").value = null
	document.getElementById("runDelServlet").value = false
	document.getElementById("runDelUrlMapping").value = false
	document.getElementById("className").value = className
	document.getElementById("delServletForm").submit()
}
</script>
</html>
