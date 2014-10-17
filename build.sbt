organization := "com.qifun"

name := "haxe-import-csv"

version := "0.2.0-SNAPSHOT"

haxeSettings

haxeJavaSettings

haxeCSharpSettings

for {
  c <- Seq(Compile, Test, CSharp, TestCSharp)
} yield {
  haxeOptions in c ++=
    Seq(
      "-lib", "continuation",
      "-lib", "haxeparser",
      "-lib", "hxparse",
      "-D", "using_worksheet")
}

for (c <- Seq(CSharp, TestCSharp)) yield {
  haxeOptions in c ++= Seq("-D", "dll")
}

haxeOptions in Test ++= Seq("--macro", "com.qifun.util.locale.Translator.addTranslationFile('zh_CN.GBK','com/qifun/importCsv/translation.zh_CN.GBK.json')")

haxeOptions in Test ++= Seq("--macro", "com.qifun.importCsv.Importer.importCsv(['com/qifun/importCsv/TestConfig.xlsx.Foo.utf-8.csv','com/qifun/importCsv/TestConfig.xlsx.Sheet2.utf-8.csv','com/qifun/importCsv/TestConfig.xlsx.Sheet3.utf-8.csv','com/qifun/importCsv/TestConfig.xlsx.import.utf-8.csv','com/qifun/importCsv/TestConfig.xlsx.using.utf-8.csv'])")

haxeOptions in Test ++= Seq("-main", "com.qifun.importCsv.ImporterTest")

sourceGenerators in TestHaxe <+= Def.task {
  val xlsxBase = (sourceDirectory in TestHaxe).value
  val unzippedBase = (sourceManaged in TestHaxe).value
  val unzipXlsx = FileFunction.cached(
    streams.value.cacheDirectory / ("unzip_xlsx_" + scalaVersion.value),
    inStyle = FilesInfo.lastModified,
    outStyle = FilesInfo.exists) { xlsxFiles: Set[File] =>
      streams.value.log.info(s"Unzipping ${xlsxFiles.size} XLSX files...")
      for {
        xlsxFile <- xlsxFiles
        if !xlsxFile.isHidden // 跳过备份文件
        outputFile <- IO.unzip(xlsxFile, unzippedBase / xlsxFile.relativeTo(xlsxBase).get.toString)
      } yield outputFile
    }
  unzipXlsx((xlsxBase ** "*.xlsx").get.toSet).toSeq
}

libraryDependencies += "com.qifun" % "haxe-util" % "0.1.1" % HaxeJava classifier("haxe-java")

crossScalaVersions := Seq("2.11.2")

homepage := Some(url(s"https://github.com/qifun/${name.value}"))

startYear := Some(2014)

licenses := Seq("Apache License, Version 2.0" -> url("http://www.apache.org/licenses/LICENSE-2.0.html"))

publishTo <<= (isSnapshot) { isSnapshot: Boolean =>
  if (isSnapshot)
    Some("snapshots" at "https://oss.sonatype.org/content/repositories/snapshots")
  else
    Some("releases" at "https://oss.sonatype.org/service/local/staging/deploy/maven2")
}

scmInfo := Some(ScmInfo(
  url(s"https://github.com/qifun/${name.value}"),
  s"scm:git:git://github.com/qifun/${name.value}.git",
  Some(s"scm:git:git@github.com:qifun/${name.value}.git")))

pomExtra :=
  <developers>
    <developer>
      <id>Atry</id>
      <name>杨博 (Yang Bo)</name>
      <timezone>+8</timezone>
      <email>pop.atry@gmail.com</email>
    </developer>
    <developer>
      <id>zxiy</id>
      <name>张修羽 (Zhang Xiuyu)</name>
      <timezone>+8</timezone>
      <email>95850845@qq.com</email>
    </developer>
  </developers>

// vim: sts=2 sw=2 et
