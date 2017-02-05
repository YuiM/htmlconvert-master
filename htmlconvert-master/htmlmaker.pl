#!/usr/local/bin/perl
package htmlmaker;
use strict;
use warnings;

#置換えするディレクトリの指定
our $dirset = 'C:/Users/xxx/Desktop/temp';

my %INDEX_INDENT = ( # インデントあってもIndex認識
    '●', 0x31,    # 太字＋下線
    '◆', 0x12 );  # 下線

my %INDEX_NOINDENT = ( # インデント無い場合にIndex認識
    '1\.', 0x34,  # 全て太字＋下線＋青
    '2\.', 0x34,
    '3\.', 0x34,
    '4\.', 0x34,
    '5\.', 0x34,
    '6\.', 0x34,
    '7\.', 0x34,
    '8\.', 0x34,
    '9\.', 0x34 );


# =============================================================================
# ここから下は変更しないで下さい
# =============================================================================

my $PROGNAME = 'htmlmaker.pl'; # プログラム名
my $PROGVER = '2015.09.13';   # Version番号
my $DEBUG = 0;                # デバッグフラグ

# +--------------------------------+
# | シェル側でエラー処理するための |
# | グローバルエラーコード         |
# | (そんなに無いけど、念のため)   |
# +--------------------------------+
my $ERR_ARGNUM   = 0x01; # 0000 0001 - コマンドライン引数
my $ERR_FOPEN    = 0x02; # 0000 0010 - ファイルOpen
my $ERR_MEMALLOC = 0x04; # 0000 0100 - Memory確保


#変換数カウント用
our $countok = 0;
our $countng = 0;
our $gKanjiCode = 'shift_jis';
#our $INDEX_INDENT;
#my $outfile;

#ディレクトリ内の情報取得
opendir(DIR , $dirset);
while(our $view = readdir(DIR))
{
	push(our @dirlist,$view);
}

foreach our $tmp (our @dirlist)
{
	if ($tmp =~ /\.txt$/i)
	{
		&HtmlConv($tmp);
	}
}

#完了メッセージを表示する
print "Content-type: text/html\n\n";
print "<META http-equiv=\"Content-Type\" content=\"text/html; charset=Shift_JIS\">\n";
print "HTMLファイルへの変換が終了しました。（正常$countok個）<BR>\n";
print "HTMLファイルへの変換が終了しました。（異常$countng個）<BR>\n";

exit;
# +=====================+
# | Txt → Html変換関数 |
# +=====================+
sub HtmlConv {
    $countok = $countok+1;	
    my ($FileName, $KanjiCode) = @_;
    my $ret = 0;
    my @dataList = (0);  # 変換元データスリスト
    my @indexList = (0); # インデックスリスト
    my $outfile = ""; 
    $outfile = $FileName;
    #$outfile = ~s/.txt//;
    $outfile = $outfile . '.html';
    
    #書き出すファイルをオープンする。
    return my $ERR_FOPEN if(! open(Fout,">$outfile"));
    
    
    my $ret = StackData($FileName, \@dataList);      # 変換元データスタック
    return $ret if ($ret);  # FatalはErrCode持って脱出
    $ret = ExtractIndex(\@dataList, \@indexList); # インデックス抽出
    return $ret if ($ret);  # FatalはErrCode持って脱出
    
    #書き出し用のファイルを作る。
    
    OutputHtmlHead($FileName, $KanjiCode);   # ヘッダ出力
    OutputTitle(\@indexList) if (my $SPECIAL);  # タイトル出力(特別機能)
    OutputIndex(\@indexList) if (my $INDEXOUT); # インデックス出力
    OutputBody(\@dataList);                  # 本文出力
    OutputHtmlFoot();                        # フッタ出力
    
    #ファイルを閉じる
    close(Fout);
    return $ret;
}


# +----------+
# | 本文出力 |
# +----------+
sub OutputBody {
    my ($rDataList) = @_;
    
    foreach my $read (@$rDataList) {
        if (CheckIndexStr(\$read)) {
            HtmlIndexStrConv(\$read);
        } else {
            HtmlStrConv(\$read);
        }
        print Fout $read;
    }
}


# +-------------------------------+
# | Index指定文字列の修飾タグ付加 |
# +-------------------------------+
sub HtmlIndexStrConv {
    my ($rRead) = @_;
    my @key_IndexIndent = keys( %INDEX_INDENT);
    my @key_IndexNoIndent = keys( %INDEX_NOINDENT);
    my $keyflag;
    my @ConvStrs = ('Front','Back');

    $keyflag = 0;
    foreach my $keyindent (@key_IndexIndent) {
        if (($$rRead =~ /^\s*$keyindent/) | ($$rRead =~ /^$keyindent/)) {
            HtmlStrConv($rRead);
            @ConvStrs = GenerateConvStrsIndent($rRead, $keyindent);
            $keyflag = 1;
            last;
        }
    }
    
    if (not $keyflag) {
        foreach my $keynoindent ($rRead, @key_IndexNoIndent) {
            if ($$rRead =~ /^$keynoindent/) {
                HtmlStrConv($rRead);
                @ConvStrs = GenerateConvStrsNoIndent($rRead, $keynoindent);
                $keyflag = 1;
                last;
            }
        }
    }
    
    HtmlStrConv($rRead) if (not $keyflag); # 実行されないはずだが
}


# +-------------------------------------+
# | インデントIndex文字列の修飾タグ付加 |
# | この関数コード汚い。今度直そう      |
# +-------------------------------------+
sub GenerateConvStrsIndent {
    my ($rRead, $KeyChar) = @_;
    my $front = '';
    my $fontfront = '';
    my $back = '';
    my $fontback = '';
    my $convCode = 0;
    #my $INDEX_INDENT;
    #my $KeyChar;
        
    $convCode = $INDEX_INDENT{$KeyChar};
    
    if ($convCode & 0x70) { # このブロックはIndent/NoIndentで非共通
        if ($convCode & 0x40) { # 斜体
            $front = $front.'<I>';
            $back = '</I>'.$back;
        }
        if ($convCode & 0x10) { # 下線
            $front = $front.'<U>';
            $back = '</U>'.$back;
        }
        if (my $SPECIAL) {
            if ($convCode & 0x20) { # 太字は指定文字列を挟む
                $front = $front.$KeyChar.'<B>';
                $back = '</B>'.$back;
            }
        } else {
            if ($convCode & 0x20) { # 太字
                $front = $front.'<B>';
                $back = '</B>'.$back;
            }
        }
    }
    if (my $SPECIAL) {
        FontTagAdd($convCode, \$fontfront, \$fontback);
        $front = $fontfront.$front;
        $back = $back.$fontback;
        $$rRead =~ s/$KeyChar/$front/;
    } else {
        FontTagAdd($convCode, \$front, \$back);
        $$rRead =~ s/$KeyChar/$front$KeyChar/;
    }
    
    $$rRead =~ s/<BR>/$back<BR>/;
}


# +---------------------------------------+
# | 非インデントIndex文字列の修飾タグ付加 |
# +---------------------------------------+
sub GenerateConvStrsNoIndent {
    my ($rRead, $KeyChar) = @_;
    my $front = '';
    my $back = '';
    my $convCode = 0;
    
    $convCode = $INDEX_NOINDENT{$KeyChar};
    
    if ($convCode & 0x70) { # このブロックはIndent/NoIndentで非共通
        if ($convCode & 0x40) { # 斜体
            $front = $front.'<I>';
            $back = '</I>'.$back;
        }
        if ($convCode & 0x20) { # 太字
            $front = $front.'<B>';
            $back = '</B>'.$back;
        }
        if ($convCode & 0x10) { # 下線
            $front = $front.'<U>';
            $back = '</U>'.$back;
        }
    }
    
    FontTagAdd($convCode, \$front, \$back);
    
    $$rRead =~ s/^/$front/;
    $$rRead =~ s/<BR>/$back<BR>/;
}


# +-------------------------------+
# | Index文字列への<FONT>タグ追加 |
# +-------------------------------+
sub FontTagAdd {
    my ($ConvCode, $rFront, $rBack) = @_;
    
    if ($ConvCode & 0x07) {
        $$rFront = $$rFront.'<FONT COLOR="#';

        if ($ConvCode & 0x04) { # 赤
            $$rFront = $$rFront.'FF';
        } else {
            $$rFront = $$rFront.'00';
        }
        if ($ConvCode & 0x02) { # 緑
            $$rFront = $$rFront.'FF';
        } else {
            $$rFront = $$rFront.'00';
        }
        if ($ConvCode & 0x01) { # 青
            $$rFront = $$rFront.'FF';
        } else {
            $$rFront = $$rFront.'00';
        }
        
        $$rFront = $$rFront.'">';
        $$rBack = '</FONT>'.$$rBack;
    }
}


# +----------------------------------------------+
# | タイトル修飾出力                             |
# | 作者の好み機能なので、修飾設定はローカルです |
# +----------------------------------------------+
sub OutputTitle {
    my ($rIndexList) = @_;
    my $title = $$rIndexList[0];
    
    chomp($title);       # 改行削除
    $title =~ s/^\s*//;  # 先頭スペース削除
    HtmlStrConv(\$title);
    
    print Fout '<B><U><FONT SIZE="+2" COLOR="#FF0000">';
    print Fout $title;
    print Fout '</FONT></U></B>',"\n";
}


# +----------------+
# | HTMLフッタ出力 |
# +----------------+
sub OutputHtmlFoot {
    print Fout '</NOBR></TT></BODY>',"\n";
    print Fout '</HTML>',"\n";
}


# +------------------+
# | インデックス出力 |
# +------------------+
sub OutputIndex {
    my ($rIndexList) = @_;
    my $read;
    
    print Fout '<HR>',"\n";
    print Fout '<B>[Index]</B><BR>',"\n";
    foreach my $readpipe (@$rIndexList) {
        $read = $readpipe;    # 元データには手を付けない
        HtmlStrConv(\$read);
        print Fout '　',"$read";
    }
    print Fout '<HR>',"\n";
}


# +---------------------------------------------+
# | 文字列のHTML変換                            |
# | Cで書いたら結構ゴチャゴチャするところだなぁ |
# +---------------------------------------------+
sub HtmlStrConv {
    my ($rRead) = @_;
    my $tabchar;

    for (my $index = 0; $index < my $TABNUM; $index++) { # TABを全角スペース×
        $tabchar .= '　';                             # $TABNUMに変換
    }

    $$rRead =~ s/&/&amp;/g;
    $$rRead =~ s/</&lt;/g;
    $$rRead =~ s/>/&gt;/g;
    $$rRead =~ s/"/&quot;/g;

    $$rRead =~ s/  /　/g;  # ここが肝。半角スペース×2を全角スペースに変換
                           # することでブラウザに「非スペース文字」だと思い
                           # 込ませる。
    $$rRead =~ s/\t/$tabchar/g; # TAB変換

    $$rRead =~ s/\n/<BR>\n/;
}


# +------------------------------------+
# | HTMLヘッダ領域(<HTML>～<BODY>)出力 |
# +------------------------------------+
sub OutputHtmlHead {
    my ($FileName, $KanjiCode) = @_;
    my $kanjiTag;
    
    print Fout '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN';
    print Fout ' "http://www.w3.org/TR/html4/loose.dtd">',"\n";
    print Fout '<HTML LANG="ja">',"\n";
    print Fout '<HEAD>',"\n";
    
    print Fout '  <META HTTP-EQUIV="Content-Type" CONTENT="text/html;';
    print Fout ' charset=';
    $kanjiTag = SelectKanjiCode($KanjiCode);
    print Fout $kanjiTag;
    print Fout '">',"\n";
    
    print Fout '  <TITLE>',"\n";
    $FileName =~ s/\.txt//i;
    print Fout "    $FileName\n";
    print Fout '  </TITLE>',"\n";
    #print Fout '  <',$PROGNAME,' ',$PROGVER,' by Monpe>',"\n";
    print Fout '</HEAD>',"\n";
    print Fout '<BODY><TT><NOBR>',"\n";
}


# +----------------+
# | 漢字コード選択 |
# +----------------+
sub SelectKanjiCode {
    my ($KanjiCode) = @_;
    my $kanjiTag = 'Shift_JIS';  # デフォルト漢字コード
    
    $kanjiTag = 'iso-2022-jp' if ($KanjiCode eq 'jis');
    $kanjiTag = 'EUC-JP'      if ($KanjiCode eq 'euc');
    $kanjiTag = 'UTF-8'       if ($KanjiCode eq 'utf');
    
    print STDERR "Kanji Code : $kanjiTag\n";
    
    return $kanjiTag;
}


# +-----------------+
# | Index文字列抽出 |
# +-----------------+
sub ExtractIndex {
    my ($rDataList,  # データスタックリストRef.
        $rIndexList  # インデックスリストRef.
       ) = @_;
    my $initFlag = 1;
    my $indexFlag;
    my $read;
    
    foreach my $readpipe (@$rDataList) {
        $read = $readpipe;  # 参照ではなく実体を受け取る
        if (CheckIndexStr(\$read)) {
            IndexStrModify(\$read) if (my $SPECIAL);
            if (not $initFlag) {
                return my $ERR_MEMALLOC if (not push(@$rIndexList,$read));
            } else {
                $$rIndexList[0] = $read;
                $initFlag = 0;
            }
        }
    }
    
    return 0;
}


# +-----------------------------------+
# | Index文字列SPECIAL文字変換        |
# | ●や◆はうざいので、+に変えちゃう |
# | でも本文中では変えないようにする  |
# +-----------------------------------+
sub IndexStrModify {
    my ($rRead) = @_;
    my @key_IndexIndent = keys(my %INDEX_INDENT);

    foreach my $key_indent (@key_IndexIndent) {
        if (($$rRead =~ /^\s*$key_indent/) | (($$rRead =~ /^\s*$key_indent/))) {
            $$rRead =~ s/$key_indent/+ /;
            print STDERR $$rRead if (my $DEBUG);
            last;
        }
    }
}


# +---------------------------------------+
# | 文字列がIndex修飾に該当するかチェック |
# +---------------------------------------+
sub CheckIndexStr {
    my ($rRead) = @_;
    my @key_IndexIndent = keys(my %INDEX_INDENT);
    my @key_IndexNoIndent = keys(my %INDEX_NOINDENT);
    my $indexFlag = 0;
    
    foreach my $key_indent (@key_IndexIndent) {
        if (($$rRead =~ /^\s+$key_indent/) | ($$rRead =~ /^\s*$key_indent/)) {
            $indexFlag = 1;
            last;
        }
    }
    
    if (not $indexFlag) {
        foreach my $key_noindent (@key_IndexNoIndent) {
            if ($$rRead =~ /^$key_noindent/) {
                $indexFlag = 1;
                last;
            }
        }
    }
    
    return $indexFlag;
}


# +-----------------------------+
# | リストにTxtデータをスタック |
# +-----------------------------+
sub StackData {
    my ($FileName , $rDataList) = @_;
    my $initFlag = 1;
    
    return my $ERR_FOPEN if (not open(FHsd,"<$FileName"));
    
    while (my $read = <FHsd>) {
    
        $read =~ s/　/  /g;  # インデント文字処理で誤解されるため全角スペースを
                             # 半角スペース*2に変換してしまう
        
        if (not $initFlag) {
            if (not push(@$rDataList, $read)) {
                close FHsd;
                #print STDERR "$PROGNAME $PROGVER : ";
                print STDERR "Memory Allocation Error!!\n";
                return my $ERR_MEMALLOC;
            }
        } else {
            $$rDataList[0] = $read;
            $initFlag = 0
        }
    }
    
    close FHsd;
    
    return 0;
}


# =============================================================================
# +======================+
# | ファイルOpenチェック |
# +======================+
# sub FileOpenCheck {
    # my ($FileName) = @_;
    # my $ret = 0;
    
    # if (not open(FHfoc, "<$FileName")) {
        # print STDERR "$PROGNAME $PROGVER : ";
        # print "File \[$FileName\] Open Error!!\n";
        # ShowUsage();
        # $ret = 1;
    # }
    # close FHfoc;
    
    # return $ret;
# }


# +============================+
# | コマンドライン引数チェック |
# +============================+
# sub ArgCountCheck {
    # my ($ArgCountNum) = @_;
    # my $ret = 0;
    
    # if ($ArgCountNum + 1 < 1) {
        # print STDERR "$PROGNAME $PROGVER : ";
        # print STDERR "Command Line Error!!\n";
        # ShowUsage();
        # $ret = 1;
    # }
    
    # return $ret;
# }


# +============+
# | 使用法表示 |
# +============+
sub ShowUsage {
    print STDERR "\[Usage\]\n";
    print STDERR "htmlconv.pl file_name.txt Kanji_option\n";
    print STDERR "  --> output file name : file_name.html\n";
    print STDERR "  --> Kanji_option : default - ShiftJIS\n";
    print STDERR "                   : jis     - JIS\n";
    print STDERR "                   : euc     - EUC\n";
    print STDERR "                   : utf     - UTF-8\n";
}
# =============================================================================

1;


