haxeSettings

haxeOptions ++= Seq("-lib", "continuation")

doxPlatforms := Seq("java", "cs")

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

// vim: sts=2 sw=2 et
