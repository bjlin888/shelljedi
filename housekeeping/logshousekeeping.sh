#!/bin/bash
# 日誌檔案清除程序，日誌檔案名稱樣板、存放路徑、排除檔案的設置在 logshousekeeping.conf
# 超過 logskeepdays 的日誌檔會壓縮到指定的 logarchivedkeepdir，日誌檔將從原始位置移除。
# 日誌壓縮檔將保留近 7 天。

PATH=usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin

# configuration home path
export CONFIG_HOME=/home/bjlin/eyesmedia/shell
echo "configuration home path ${CONFIG_HOME}"

findlogfilenamepatterns=""
excludetarfilenamepatterns=""
logsarchivedfilename=""

# reading configuration
config() {
   echo "Reading logshousekeeping.conf...." >&2
   if [ -f "${CONFIG_HOME}/logshousekeeping.conf" ]; then
      echo "Got ${CONFIG_HOME}/logshousekeeping.conf" >&2
      source ${CONFIG_HOME}/logshousekeeping.conf
      
      # 日誌檔壓縮檔案名稱 
      logsarchivedfilename=$(date --date "$logskeepdays days ago" +%Y%m%d%H%M%S)
      echo "logs archived file name ${logsarchivedfilename}.tar.gz"
   else
      echo "${CONFIG_HOME}/logshousekeeping.conf not found." >&2
      exit 1
   fi
}

# 將 logfilenameexcludepatterns 設定的 patterns 組裝成 --exclude="xxx" --exclude="yyy"
# 將那個樣式作為 tar 指令 排除檔案的參數
createexcludetarfilenamepatterns() {
   patternstring=`echo "${logfilenameexcludepatterns[@]}"`
   echo "exclude log file name patterns ${patternstring}"
   
   patternslen=`echo ${#logfilenameexcludepatterns[@]}`
   count=0
   findname="--exclude=@@"
   tempstr=""
   for pattern in ${logfilenameexcludepatterns[@]}; do
      if [ $count -eq 0 ]; then
         echo "pattern ${pattern}"
         excludetarfilenamepatterns=`echo $findname | sed -e "s/@@/\"$pattern\"/g"`
         echo "find log file name patterns ${excludetarfilenamepatterns}"
      else
         findname=" --exclude=\"$pattern\""
         tempstr=`echo \"${logfilenameexcludepatterns[$count-1]}\"`
         excludetarfilenamepatterns=`echo $excludetarfilenamepatterns | sed -e "s/$tempstr/&$findname/g"`
      fi
      (( count++ ))
   done;
   
   echo "find log file name patterns ${excludetarfilenamepatterns}"   
}

# do log files clean and archived to tar.gz
housekeeping() {   
   # Loop the databases
   count=0
   for logdir in ${logdirs[@]}; do
      echo "Changing directory to ${logdir}"
      cd $logdir
      echo "current working directory $(pwd)"
      
      echo "/usr/bin/find . -type f \( ${logfilenamepatterns[@]} \) -mtime +${logskeepdays} -print0 | xargs -0 tar cvzf ${logarchivedkeepdir}/${targzfilename}-${count}.tar.gz ${excludetarfilenamepatterns}"      
      # archiving log files into tar.gz
      targzfilename=`echo "${logdir}" | cut -d "/" -f6`
      targzfilename=`echo "${targzfilename}"-"${logsarchivedfilename}"`
      echo "targzfilename ${targzfilename}"
      
      filesCount=`/usr/bin/find . \( "${logfilenamepatterns[@]}" \) -type f -mtime +"${logskeepdays}" | wc -l`
      echo "filesCount ${filesCount}"
      if [ $filesCount -gt 0 ]; then   
         /usr/bin/find . \( "${logfilenamepatterns[@]}" \) -type f -mtime +"${logskeepdays}" -print0 | xargs -0 tar cvzf $logarchivedkeepdir/$targzfilename-$count.tar.gz $excludetarfilenamepatterns      
         
         # deleting log files
         /usr/bin/find . $findpatterns -type f -mtime +"${logskeepdays}" -exec rm -Rf {} \;
      else
         echo "No log files to be housekeeping."    
      fi
      
      # deleting archived files, 7 days ago
      cd $logarchivedkeepdir
      filesCount=`/usr/bin/find . *.tar.gz -type f -mtime +7 | wc -l`
      if [ $filesCount -gt 0 ]; then
         /usr/bin/find . *.tar.gz -type f -mtime +7 -exec rm -Rf {} \;
      else
        echo "No archived log files to be housekeeping."
      fi      
      
      (( count++ ))
   done;   
}

# import configuration
config

# see function description
createexcludetarfilenamepatterns

# 壓縮七天之前的所有日誌檔並清除檔案
housekeeping