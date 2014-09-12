organization := "com.qifun"

name := "haxe-import-csv"

version := "0.1.0-SNAPSHOT"

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

haxeOptions in Test ++= Seq("--macro", "com.qifun.util.locale.Translator.addTranslationFile('zh_CN.GBK','com/qifun/qforce/importCsv/translation.zh_CN.GBK.json')")

haxeOptions in Test ++= Seq("--macro", "com.qifun.qforce.importCsv.Importer.importCsv(['com/qifun/qforce/importCsv/TestConfig.xlsx.Foo.utf-8.csv','com/qifun/qforce/importCsv/TestConfig.xlsx.Sheet2.utf-8.csv','com/qifun/qforce/importCsv/TestConfig.xlsx.Sheet3.utf-8.csv','com/qifun/qforce/importCsv/TestConfig.xlsx.import.utf-8.csv','com/qifun/qforce/importCsv/TestConfig.xlsx.using.utf-8.csv'])")

haxeOptions in Test ++= Seq("-main", "com.qifun.qforce.importCsv.ImporterTest")

doxPlatforms := Seq("java", "cs", "neko")

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

// vim: sts=2 sw=2 et
