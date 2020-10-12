#include<Windows.h>
#include "trivium.h"
#include "ecrypt-sync.h"
#include <stdio.h>
#include<time.h>
#include<math.h>
#include<windows.h>

void choose_random_key(u32 KEY[])
{
	u8 i=0;
	u8 j=0;
	//srand((unsigned int) time(NULL));
	
	KEY[0]=rand()&0x000000FF;
 for(i=1;i<10;i++)
   {
	KEY[i]=rand()&0x000000FF;
LOOP: for (j=0;j<i;j++)
	  {
		if (KEY[i]==KEY[j]) 
		{
         KEY[i]=rand()&0x000000FF;
		 goto LOOP;
		}
	  }
   }

}

/////随机选择一个80的数组,然后拼成方程,然后用sat求解


/////

void tocnf(int VN, const char* stropenpath)
{
	//remove("D:\\result.txt");
	//remove("D:\\Ret.txt");
	FILE *fpsystem, *fpsystempre, *fpnlitem, *fpsatfile0, *fpsatfile;
	char Satfilepath[400];
	//char Satfile[20] = "\\"
	char NLitem[200]={0};
	char item[2000]={0};
	char ch1, ch2;
	int firstch = 0, single = 0;
	long itemlen = 0, itemnum = 0, linelen = 0;
	unsigned i = 0, j = 0, t = 0, r, s;
	int reallen = 0, tempvar = 0;
	int itemint[100] = { 0 };
	long cutlen = 40000;
	int flag;
	char prech;
	int count = 0;
	fpsystem = fopen(stropenpath, "r");
	//fopen_s(fpsystem, stropenpath, "r");
	//fpsystempre = fopen("systempre.txt", "w");
	fpsystempre = fopen("systempre", "w");

	prech = fgetc(fpsystem);//先读取一个
	//用于统计在读到0或1是总共移动了多少个字符，要移回去重新读取变量

	//while (!feof(fpsystem))
	while (feof(fpsystem)==0)
	{
		//先读到0或1然后再返回到原来的位置
		single = 0;
		while (prech != '=')
		{
			prech = fgetc(fpsystem);
			count++;
			if (prech == '+')
				single = 1;
		}
		prech = fgetc(fpsystem);
		count++;
		count = 0 - count;
		if (prech == '1'&&single == 1)
			fputc('x', fpsystempre);
		else if (prech == '0'&&single == 1)
			fputs("x-", fpsystempre);
		else if (prech == '0'&&single == 0)
			fputs("-", fpsystempre);
		else
			;
	/*	if (prech == '1')
		{
			fputc('x', fpsystempre);
		}
		else
			fputs("x-", fpsystempre);*/
		
		//fseek(fpsystem, count-1, SEEK_CUR);
		
		flag=ftell(fpsystem);
		fseek(fpsystem,0,SEEK_SET);
		fseek(fpsystem,flag+count,SEEK_SET);
		flag=ftell(fpsystem);
		prech = fgetc(fpsystem);
		count = 0;
		/*fseek(fpsystem,count-1,1);
		prech = fgetc(fpsystem);*/
		/*if(prech<'a'||(prech>'z'&&prech<'A')||prech>'Z')
			prech=fgetc(fpsystem);*/
		while (prech != '=')
		{
			if (prech == '+')
				fputc(' ', fpsystempre);
			else if (((prech >= 'a') && (prech <= 'z')) || ((prech >= 'A') && (prech <= 'Z')));
			else
			{
				if(prech!='('&&prech!=')')
					fputc(prech, fpsystempre);
			}
			prech = fgetc(fpsystem);
		}
		//如果已经输出过0，就不再输出零
		fputc(' ', fpsystempre);
		fputc('0', fpsystempre);
		fputc('\n', fpsystempre);

		prech = getc(fpsystem);
		prech = getc(fpsystem);
		prech = getc(fpsystem);
	}
	fclose(fpsystempre);
	fclose(fpsystem);

	fpsystempre = fopen("systempre", "r");
	fpnlitem = fopen("NLitem", "w");
	fpsatfile0 = fopen("satfile0", "w");
	//while (!feof(fpsystempre))
	while (feof(fpsystempre)==0)
	{
		fscanf(fpsystempre, "%s ", item);
		if ((strlen(item) == 1) && (item[0] == '0'))
			fprintf(fpsatfile0, "0\n");
		else
		{
			for (i = 0; i<strlen(item); i++)
			{
				if (item[i] == '*')
				{
					if (item[0] == 'x')
					{
						fprintf(fpsatfile0, "x");
					}
					else if (item[0] == '-')
						fprintf(fpsatfile0, "-");
					if (item[1] == '-')
					{
						fprintf(fpsatfile0, "-");
					}
					itemnum++;
					fprintf(fpsatfile0, "%d ", itemnum + VN);
					break;
				}
			}
			//如果没有*那么就是只有一个变量，保持原来的变量下标
			if (i == strlen(item))
				fprintf(fpsatfile0, "%s ", item);
		}
	}
	fclose(fpsatfile0);

	fpsatfile0 = fopen("satfile0", "r+");
	fpsatfile = fopen("satfile", "w");//换成别的参数
	
	while (feof(fpsatfile0)==0)
	{
		fscanf(fpsatfile0, "%s ", item);
		linelen++;
		if ((strlen(item) == 1) && (item[0] == '0')) //读取一个方程，linelen为方程中的项数
		{
			fprintf(fpsatfile, "0\n");
			linelen = 0;
		}
		else
		{
			if ((linelen >= cutlen) && (item != "0"))
			{
				itemnum++;
				fprintf(fpsatfile, "%d 0\nx-%d ", itemnum + VN, itemnum + VN);//每分一次就要增加一个变量
				fprintf(fpsatfile, "%s ", item);
				linelen = 1;
			}
			else
			{
				fprintf(fpsatfile, "%s ", item);
			}
		}
		memset(item,0,sizeof(char)*2000);
	}
	

	fclose(fpsatfile0);
	//把fp1中的所有非线性项提取出来放到文件fp2中,并对每个项赋一个新的变元置于每行的末尾,作为变元映射的参照
	fseek(fpsystempre, 0L, SEEK_SET);
	itemnum = 0;
	//while (!feof(fpsystempre))
	while (feof(fpsystempre)==0)
	{
		ch1 = fgetc(fpsystempre);
		if (ch1 == '*')
		{
			itemnum++;
			fseek(fpsystempre, ftell(fpsystempre) - 2L, SEEK_SET);
			ch2 = fgetc(fpsystempre);
			while ((ch2 != ' ') && (ch2 != '-') && (ch2 != 'x'))
			{
				fseek(fpsystempre, ftell(fpsystempre) - 2L, SEEK_SET);
				ch2 = fgetc(fpsystempre);
			}
			fscanf(fpsystempre, "%s", NLitem);
			for (j = 0; j<strlen(NLitem); j++)
			{
				if (NLitem[j] != '*')
				{
					fprintf(fpnlitem, "%c", NLitem[j]);
				}
				else
				{
					fprintf(fpnlitem, " ");
				}
			}
			fprintf(fpnlitem, " %d\n", itemnum + VN);
		}
		//fprintf(fpnlitem, " %d\n", itemnum + VN);
	}
	fprintf(fpnlitem, "0"); //标识文件结束,为了下面进行CNF处理的方便
	fclose(fpnlitem);
	fclose(fpsystempre);

	//根据fp1和fp3在新建的用于MINISAT求解的文件fp3末尾追加上由fp3中的非线性项得到的CNF
	fpnlitem = fopen("NLitem", "r");
	//while (!feof(fpnlitem))
	while (feof(fpnlitem)==0)
	{
		t = 0;
		fscanf(fpnlitem, "%d", &tempvar);
		if (tempvar != 0)
		{
			while (tempvar <= VN)
			{
				itemint[t] = tempvar;
				t++;
				fscanf(fpnlitem, "%d", &tempvar);
			}
			itemint[t] = tempvar;
			for (r=0;r<t;r++)
			{
			fprintf(fpsatfile,"%d %d 0\n",itemint[r],-itemint[t]);
			}
			for (s = 0; s<t; s++)
			{
				fprintf(fpsatfile, "%d ", -itemint[s]);
			}
			fprintf(fpsatfile, "%d 0\n", itemint[s]);
		}

	}
	fclose(fpnlitem);
	fclose(fpsatfile);
	remove("systempre");
	remove("NLitem");
	remove("satfile0");
}



void solve(int searnum,char searpath[],int equnum)
{
	//remove("E:\\Ans.txt");
	//int aa=remove("E:\\result.txt");
	char text[1000] = {0};
	int k;
	//char searpath[1000]="finequ.txt";
	char temppath[1000]="eau\0";
	int ind=0,index=0,in=0;
	//FILE * REC,*SATREC;
	//FILE *fp;
	FILE *equaltion, *fpR1;
	int sum_t=0;
	int VarNum,i,j,num,search,round=0,xiabiao=0,tsum=0,ttsum=0;
	char key[3000]={0},c;
	int ans[3000]={0},times=0,flag=0;
	FILE* fpresult, *fpR,*NewFile;
	//TCHAR szcom[] = TEXT(" E:\\satfile E:\\result.txt");
	TCHAR szcom[] = TEXT("satfile result");
	PROCESS_INFORMATION pi; //必备参数设置结束
	STARTUPINFO si;
	TCHAR ss[1000]=TEXT("2.exe satfile result\0");//用于生成第二个参数,路经加上命令行
	//TCHAR ss[1000]=TEXT("D:\\software\\1\\2.exe satfile result\0");//用于生成第二个参数,路经加上命令行
//	REC=fopen("E:\\ye\\rec.txt","wb");
//	SATREC=fopen("E:\\ye\\satrec.txt","wb");
	//REC=fopen("trec.txt","w");
	//SATREC=fopen("satrec.txt","w");

	
	memset(&si, 0, sizeof(STARTUPINFO)); //初始化si在内存块中的值
	si.cb = sizeof(STARTUPINFO);
	si.dwFlags = STARTF_USESHOWWINDOW|STARTF_USESTDHANDLES;
	si.wShowWindow = SW_HIDE;
	/*si.dwFlags = STARTF_USESHOWWINDOW;
	si.wShowWindow = SW_SHOW;*/
	


	j = 0;
	//该程序采用的特例是变量个数为116，方程个数为108，遍历的变量个数最多是80
	num=equnum;VarNum=100;search=80;
	
	/*if((fp=fopen("E:\\Ans.txt","r"))!=NULL)
		system("del E:\\Ans.txt");*/
	
	//开始循环
	//加一层循环,要取十组初值进行验证
	//ftime=fopen("timerec.txt","rb+");
	tsum=0;ttsum=0;
	
	for (k =0; k <searnum;k++)
	{
		if(k!=0)
		{
			times =k+1;
			equaltion= fopen(searpath, "a+");	
			fprintf(equaltion,"s%d=%d\n", (k / 2 + 1), k % 2);
			fclose(equaltion);
		}
	tocnf(VarNum, searpath);
	CreateProcess(NULL, ss, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi);//调用程序
	WaitForSingleObject(pi.hProcess, INFINITE);
	CloseHandle(pi.hThread);
	CloseHandle(pi.hProcess);
	i = 0;
	//fpresult = fopen("E:\\result.txt", "rb");
	//fpR1 = fopen("E:\\Ans.txt", "a+");
	fpresult = fopen("result", "rb");
	fpR1 = fopen("Ans", "a+");
	
	if (fpresult)
	{
		//读入一行，首先将原来的格式转换
		xiabiao=0;
		fgets(text, 10, fpresult);
		//fpR = fopen("E:\\temp.txt", "wb");
		fpR = fopen("temp", "w");
		if (text[0] == 'U')
			//MessageBox(_T("Unsat"));
		{
			//fprintf(fpR1, "\nUnsat\n");
			/*fprintf(REC,"%s",searpath);
			fprintf(REC,"  Unsat\n");*/
			//printf("Unsat\n");
		}
		else
		{
			while (!feof(fpresult))
			{
				fscanf(fpresult, "%s ", text);
				if (text[0] == '-')
				{
					if(xiabiao<VarNum)
					{
					//fprintf(fpR1, "x[");
					//fprintf(fpR1, text + 1);
					//fprintf(fpR1, "]=0\n");
						c='0';
						fprintf(fpR1, "%c,",c);
					ans[xiabiao]=0;
					xiabiao++;
					}
					memset(text, 0, sizeof(char)* 1000);

				}
				else if (text[0] == '0')
					break;
				else
				{
					if(xiabiao<VarNum)
					{
					/*fprintf(fpR1, "x[");
					fprintf(fpR1, text);
					fprintf(fpR1, "]=1\n");*/
						c='1';
						fprintf(fpR1, "%c,",c);
					ans[xiabiao]=1;
					xiabiao++;
					}
					memset(text, 0, sizeof(char)* 1000);
				}

			}
			if(xiabiao==VarNum)
				fprintf(fpR1,"\n");
			fclose(fpR);
			fclose(fpresult);
		}
		//fclose(fp);
	}
	fclose(fpR1);
	//printf("solve done>>>>\n");
	equaltion = fopen(searpath, "r+");
	
	NewFile = fopen(temppath, "w");
	for (i = 0; i <num; i++)
	{
		memset(text, 0, 1000 * sizeof(char));
		fscanf(equaltion, "%s\n", text); 
		fprintf(NewFile, "%s\n", text);
	}

	//

	//删除原文件，重命名
	fclose(equaltion);
	fclose(NewFile);
	remove(searpath);
	rename(temppath, searpath);//
	//remove(temppath); 
	if(flag==1)
	{
		break;
	}
	}
	
}


u32 getsolnum(u8  sol[][80])
{
	u32 j;
	u32 qq,tt,l,l2,l3,k1,k2,k3;
	FILE *fp;
	char c1,flag,buf1[1000];
	u32 tempcube[1000];
	//fp=fopen("Ans.txt","r");
	fp=fopen("Ans","r");
	j=0;
	c1=fgetc(fp);
	while(c1!=EOF&&(j<100))
	{

		flag=0;
		l=0;l2=0;l3=0;
		k1=0;k2=0;k3=0;
		//c1=fgetc(fp);
		//c2=fgetc(fp2);
		//c3=fgetc(fp3);
		while(c1!='\n')
		{
			//memset(tempcube,0,sizeof(char)*1000);
			if(c1!=',')
			{
				buf1[k1]=c1;
				c1=fgetc(fp);
				k1++;
			}
			else
			{
				//memset(tempcube,0,sizeof(char)*1000);
				if(k1==1)
					//cubeGF[j][l]=buf1[0]-'0';
					tempcube[l]=buf1[0]-'0';
				else
					//cubeGF[j][l]=(buf1[0]-'0')*10+(buf1[1]-'0');
					tempcube[l]=(buf1[0]-'0')*10+(buf1[1]-'0');
				l++;
				c1=fgetc(fp);
				memset(buf1,0,sizeof(char)*1000);
				k1=0;
			}
		}
		c1=fgetc(fp);
		if(j==0)
		{
			for(tt=0;tt<l;tt++)
				sol[j][tt]=tempcube[tt];
				
			j++;
			memset(tempcube,0,sizeof(char)*1000);
		}
		else
		{
			for(qq=0;qq<j;qq++)
			{
				
					for(tt=0;tt<80;tt++)
					{
						if(tempcube[tt]!=sol[qq][tt])
							break;
					}
			if(tt==l)
				break;	

			}
			if(qq==j)
			{
				
				//flag=1;
				for(tt=0;tt<l;tt++)
					sol[j][tt]=tempcube[tt];
				j++;
			}
			memset(tempcube,0,sizeof(char)*1000);
		}
		memset(buf1,0,sizeof(char)*1000);
	}
	fclose(fp);
	return j;
}
//直接把全部的取好
void genrandomkey(u32 randomkey[][10],u32 twokeysum[][10])
{
	FILE *fp,*fp2;
	u32 tempkey[64][10];
	u32 i,keynum=64,j,k,searnum=40;
	//u32 rh[80];
	u32 solnum,temp;
	u32 pick,equnum=30;
	u8 sol[100][80];
	char searpath[1000]="finequ\0";
	char c,buffer[288][3000],rand1[64][288],rand2[64][288],rand3[64][288];
	char change[23]={60,61,120,121,122,129,130,131,147,148,156,157,198,199,201,213,214,215,225,226,227,240,241};
	char change1[16]={20,21,89,90,107,108,116,117,158,159,160,185,186,187,200,201};
	char change2[16]={2,3,13,14,5,6,8,9,11,20,21,23};
	char flag[288]={0};
	fp=fopen("equV4","r");
	for(i=0;i<4;i++)
		flag[change2[i]]=1;

	for(i=0;i<64;i++)
		for(j=0;j<288;j++)
			rand1[i][j]=rand()%2;

	for(i=0;i<64;i++)
		for(j=0;j<288;j++)
			rand2[i][j]=rand()%2;

	for(i=0;i<64;i=i+2)
		for(j=0;j<288;j++)
			rand3[i][j]=rand1[i][j]^rand1[i+1][j];

	for(i=0;i<keynum;i++)
		choose_random_key(tempkey[i]);
	for(i=0;i<288;i++)
		for(j=0;j<3000;j++)
			buffer[i][j]=0;
	c=fgetc(fp);
	for(i=0;i<equnum;i++)
	{
		j=0;
		while(c!='\n')
		{
			buffer[i][j++]=c;
			c=fgetc(fp);
			//printf("%c",c);
		}
		c=fgetc(fp);
		//printf("%c",c);
	}
	//确定每一个二次项的取值
	srand((unsigned int) time(NULL));
	//fclose(fp2);
	for(i=0;i<keynum;i++)
	{
		fp2=fopen("finequ","w");
		for(j=0;j<equnum;j++)
		{
			k=0;
			while(buffer[j][k]!='\0')
			{
				fprintf(fp2,"%c",buffer[j][k]);
				k++;
			}
			//随机密钥是否有问题,对方程的赋值
			fprintf(fp2,"=");
			//fprintf(fp2,"%d\n",(tempkey[i][j>>3]>>(j&0x07))&0x01);
			//288个方程
			fprintf(fp2,"%d\n",rand1[i][j]^flag[j]);
		}
		fclose(fp2);
		//调用SAT求解器,求解fin方程的所有可能的解
		//slove();
		solve(searnum,searpath,equnum);
		solnum=getsolnum(sol);
		/*if((fp2=fopen("E:\\Ans.txt","r")))
		{
				fclose(fp);*/
		//system("del E:\\Ans.txt");
		//system("del Ans.txt");
		system("del Ans");
		//}
		//将文件中的解返回,然后随机选取一个解
		//解得数量控制在100组内,读取后需要去重
		//解得形式:80个0,1,对应的是key0到key80,在拼装的时候注意顺序
		pick=rand()%solnum;
		for(j=0;j<10;j++)
		{
			temp=0;
			for(k=0;k<8;k++)
				temp=temp^(sol[pick][j*8+k]<<k);
			randomkey[i][j]=temp;
		}

	}
	/////两个密钥之和
	for(i=0;i<100;i++)
		for(j=0;j<80;j++)
			sol[i][j]=0;

	for(i=0;i<keynum;i=i+2)
	{
		fp2=fopen("finequ","w");
		for(j=0;j<equnum;j++)
		{
			k=0;
			while(buffer[j][k]!='\0')
			{
				fprintf(fp2,"%c",buffer[j][k]);
				k++;
			}
			fprintf(fp2,"=");
			//fprintf(fp2,"%d\n",((tempkey[i][j>>3]>>(j&0x07))&0x01)^((tempkey[i+1][(j)>>3]>>(j&0x07))&0x01));
			fprintf(fp2,"%d\n",rand1[i][j]^rand1[i+1][j]);
		}
		fclose(fp2);
		//调用SAT求解器,求解fin方程的所有可能的解,返回解得数量
		solve(searnum,searpath,equnum);
		solnum=getsolnum(sol);
		//将文件中的解返回,然后随机选取一个解
		//解得数量控制在100组内,读取后需要去重
		//解得形式:80个0,1,对应的是key0到key80,在拼装的时候注意顺序
		//system("del E:\\Ans.txt");
		//system("del Ans.txt");
		system("del Ans");
		pick=rand()%solnum;
		for(j=0;j<10;j++)
		{
			temp=0;
			for(k=0;k<8;k++)
				temp=temp|(sol[pick][j*8+k]<<k);
			twokeysum[i/2][j]=temp;//只有一半
		}
		


	}

}



//先取好a和b,然后,将ab分别运算之特殊形式,然后解方程
void genrandomkeyV2(u32 randomkey[][10],u32 twokeysum[][10])
{
	FILE *fp,*fp2;
	u32 tempkey[80][10];
	u32 i,keynum=48,j,k,searnum=80,rh[80]={0};
	//u32 rh[80];
	u32 solnum,temp;
	u32 pick,equnum=76;
	u8 sol[100][80];
	char searpath[1000]="finequ\0";
	char c,buffer[80][80];
	fp=fopen("equ","r");
	for(i=0;i<80;i++)
		for(j=0;j<80;j++)
			buffer[i][j]=0;
	c=fgetc(fp);
	for(i=0;i<equnum;i++)
	{
		j=0;
		while(c!='\n')
		{
			buffer[i][j++]=c;
			c=fgetc(fp);
		}
		c=fgetc(fp);
	}
	fclose(fp);
	///*for(i=0;i<keynum;i++)
	//	choose_random_key(tempkey[i]);*/
	////直接随机选的
	//for(i=0;i<keynum;i++)
	//	for(j=0;j<10;j++)
	//		tempkey[i][j]=randomkey[i][j];
	
	for(i=0;i<keynum;i++)
		choose_random_key(tempkey[i]);
	//直接随机选的
	for(i=0;i<keynum;i++)
		for(j=0;j<10;j++)
			randomkey[i][j]=tempkey[i][j];
	

	/////两个密钥之和
	for(i=0;i<100;i++)
		for(j=0;j<80;j++)
			sol[i][j]=0;

	for(i=0;i<keynum;i=i+2)
	{
		fp2=fopen("finequ","w");
		for(j=0;j<equnum;j++)
		{
			//rh[j]=(((tempkey[i][(3*j)>>3]>>((3*j)&0x07))&0x01)&((tempkey[i][(3*j+1)>>3]>>((3*j+1)&0x07))&0x01))^((tempkey[i][(3*j+2)>>3]>>((3*j+2)&0x07))&0x01);
			//temp=(((tempkey[i+1][(3*j)>>3]>>((3*j)&0x07))&0x01)&((tempkey[i+1][(3*j+1)>>3]>>((3*j+1)&0x07))&0x01))^((tempkey[i+1][(3*j+2)>>3]>>((3*j+2)&0x07))&0x01);
			//temp=(((tempkey[i+1][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+1][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+1][(j+27)>>3]>>((j+27)&0x07))&0x01)((tempkey[i+1][(j)>>3]>>((j)&0x07))&0x01);
			temp=(((tempkey[i+1][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+1][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+1][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i+1][(j)>>3]>>((j)&0x07))&0x01);
			rh[j]=(((tempkey[i][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i][(j)>>3]>>((j)&0x07))&0x01);
			rh[j]=temp^rh[j];
			k=0;
			while(buffer[j][k]!='\0')
			{
				fprintf(fp2,"%c",buffer[j][k]);
				k++;
			}
			fprintf(fp2,"=");
			fprintf(fp2,"%d\n",rh[j]);
		}
		fclose(fp2);
		//调用SAT求解器,求解fin方程的所有可能的解,返回解得数量
		//printf("Solve Begin\n");
		solve(searnum,searpath,equnum);
		//printf("Solve Done\n");
		solnum=getsolnum(sol);
		//将文件中的解返回,然后随机选取一个解
		//解得数量控制在100组内,读取后需要去重
		//解得形式:80个0,1,对应的是key0到key80,在拼装的时候注意顺序
		//system("del E:\\Ans.txt");
		//system("del Ans.txt");
		system("del Ans");
		pick=rand()%solnum;
		for(j=0;j<10;j++)
		{
			temp=0;
			for(k=0;k<8;k++)
				temp=temp|(sol[pick][j*8+k]<<k);
			twokeysum[i/2][j]=temp;//只有一半
		}
		


	}

}


void genrandomkeyV2Right(u32 randomkey[][10],u32 twokeysum[][10])
{
	FILE *fp,*fp2;
	u32 tempkey[256][10];
	u32 i,keynum=256,j,k,searnum=80,rh[80]={0};
	//u32 rh[80];
	u32 solnum,temp,jj;
	u32 pick,equnum=53;
	u8 sol[1000][80];
	char searpath[1000]="finequ\0";
	char c,buffer[80][80];
	fp=fopen("equ","r");
	for(i=0;i<80;i++)
		for(j=0;j<80;j++)
			buffer[i][j]=0;
	c=fgetc(fp);
	for(i=0;i<equnum;i++)
	{
		j=0;
		while(c!='\n')
		{
			buffer[i][j++]=c;
			c=fgetc(fp);
		}
		c=fgetc(fp);
	}
	fclose(fp);
	///*for(i=0;i<keynum;i++)
	//	choose_random_key(tempkey[i]);*/
	////直接随机选的
	//for(i=0;i<keynum;i++)
	//	for(j=0;j<10;j++)
	//		tempkey[i][j]=randomkey[i][j];
	
	for(i=0;i<keynum;i++)
		choose_random_key(tempkey[i]);
	//直接随机选的
	for(i=0;i<keynum;i++)
		for(j=0;j<10;j++)
			randomkey[i][j]=tempkey[i][j];
	

	/////两个密钥之和
	for(i=0;i<100;i++)
		for(j=0;j<80;j++)
			sol[i][j]=0;

	for(i=0;i<keynum;i=i+2)
	{
		fp2=fopen("finequ","w");
		for(j=0;j<equnum;j++)
		{
			//rh[j]=(((tempkey[i][(3*j)>>3]>>((3*j)&0x07))&0x01)&((tempkey[i][(3*j+1)>>3]>>((3*j+1)&0x07))&0x01))^((tempkey[i][(3*j+2)>>3]>>((3*j+2)&0x07))&0x01);
			//temp=(((tempkey[i+1][(3*j)>>3]>>((3*j)&0x07))&0x01)&((tempkey[i+1][(3*j+1)>>3]>>((3*j+1)&0x07))&0x01))^((tempkey[i+1][(3*j+2)>>3]>>((3*j+2)&0x07))&0x01);
			//temp=(((tempkey[i+1][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+1][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+1][(j+27)>>3]>>((j+27)&0x07))&0x01)((tempkey[i+1][(j)>>3]>>((j)&0x07))&0x01);
			if(j<53)
			{
			temp=(((tempkey[i+1][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+1][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+1][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i+1][(j)>>3]>>((j)&0x07))&0x01);
			rh[j]=(((tempkey[i][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i][(j)>>3]>>((j)&0x07))&0x01);
			}
			else
			{
				jj=j-53;
				temp=(((tempkey[i+1][(jj+1)>>3]>>((jj+1)&0x07))&0x01)&((tempkey[i+1][(jj)>>3]>>((jj)&0x07))&0x01))^((tempkey[i+1][(jj+44)>>3]>>((jj+44)&0x07))&0x01)^((tempkey[i+1][(jj+2)>>3]>>((jj+2)&0x07))&0x01);
				rh[j]=(((tempkey[i][(jj+1)>>3]>>((jj+1)&0x07))&0x01)&((tempkey[i][(jj)>>3]>>((jj)&0x07))&0x01))^((tempkey[i][(jj+44)>>3]>>((jj+44)&0x07))&0x01)^((tempkey[i][(jj+2)>>3]>>((jj+2)&0x07))&0x01);

			}
			rh[j]=temp^rh[j];
			k=0;
			while(buffer[j][k]!='\0')
			{
				fprintf(fp2,"%c",buffer[j][k]);
				k++;
			}
			fprintf(fp2,"=");
			fprintf(fp2,"%d\n",rh[j]);
		}
		fclose(fp2);
		//调用SAT求解器,求解fin方程的所有可能的解,返回解得数量
		//printf("Solve Begin\n");
		solve(searnum,searpath,equnum);
		//printf("Solve Done\n");
		solnum=getsolnum(sol);
		//将文件中的解返回,然后随机选取一个解
		//解得数量控制在100组内,读取后需要去重
		//解得形式:80个0,1,对应的是key0到key80,在拼装的时候注意顺序
		//system("del E:\\Ans.txt");
		//system("del Ans.txt");
		system("del Ans");
		pick=rand()%solnum;
		for(j=0;j<10;j++)
		{
			temp=0;
			for(k=0;k<8;k++)
				temp=temp|(sol[pick][j*8+k]<<k);
			twokeysum[i/2][j]=temp;//只有一半
		}
	}

}


void GenRandomKeyV3Right(u32 randomkey[][10],u32 twokeysum[][10])
{
	FILE *fp,*fp2;
	u32 tempkey[256][10];
	u32 i,keynum=256,j,k,searnum=80,rh[80]={0},rh2[80]={0};
	//u32 rh[80];
	u32 solnum,temp,jj;
	u32 pick,equnum=25;
	u8 sol[1000][80];
	char searpath[1000]="finequ2\0";
	char c,buffer[80][80];
	fp=fopen("equ2","r");
	for(i=0;i<80;i++)
		for(j=0;j<80;j++)
			buffer[i][j]=0;
	c=fgetc(fp);
	for(i=0;i<equnum;i++)
	{
		j=0;
		while(c!='\n')
		{
			buffer[i][j++]=c;
			c=fgetc(fp);
		}
		c=fgetc(fp);
	}
	fclose(fp);
	
	/*for(i=0;i<keynum;i++)
		choose_random_key(tempkey[i]);*/
	//直接随机选的
	for(i=0;i<keynum;i++)
		for(j=0;j<10;j++)
			tempkey[i][j]=randomkey[i][j];
	

	/////两个密钥之和
	for(i=0;i<100;i++)
		for(j=0;j<80;j++)
			sol[i][j]=0;

	for(i=0;i<keynum;i=i+2)
	{
		fp2=fopen("finequ2","w");
		for(j=0;j<equnum;j++)
		{
			if(j<1)
			{
				rh[j]=((tempkey[i][j>>3]>>(j&0x07))&0x01)&((tempkey[i][(j+1)>>3]>>((j+1)&0x07))&0x01)^((tempkey[i][(j+2)>>3]>>((j+2)&0x07))&0x01)^((tempkey[i][(j+44)>>3]>>((j+44)&0x07))&0x01);
				rh2[j]=((tempkey[i+1][j>>3]>>(j&0x07))&0x01)&((tempkey[i+1][(j+1)>>3]>>((j+1)&0x07))&0x01)^((tempkey[i+1][(j+2)>>3]>>((j+2)&0x07))&0x01)^((tempkey[i+1][(j+44)>>3]>>((j+44)&0x07))&0x01);

			}
			if(j>0&&j<13)
			{
				rh[j]=((tempkey[i][j>>3]>>(j&0x07))&0x01)&((tempkey[i][(j+1)>>3]>>((j+1)&0x07))&0x01)^((tempkey[i][(j+2)>>3]>>((j+2)&0x07))&0x01)^((tempkey[i][(j+44)>>3]>>((j+44)&0x07))&0x01)^((tempkey[i][(j+53)>>3]>>((j+53)&0x07))&0x01);
				rh2[j]=((tempkey[i+1][j>>3]>>(j&0x07))&0x01)&((tempkey[i+1][(j+1)>>3]>>((j+1)&0x07))&0x01)^((tempkey[i+1][(j+2)>>3]>>((j+2)&0x07))&0x01)^((tempkey[i+1][(j+44)>>3]>>((j+44)&0x07))&0x01)^((tempkey[i+1][(j+53)>>3]>>((j+53)&0x07))&0x01);
			}
			if(j>12&&j<25)
			{
				
				rh[j]=((tempkey[i][j>>3]>>(j&0x07))&0x01)&((tempkey[i][(j+1)>>3]>>((j+1)&0x07))&0x01)^((tempkey[i][(j+2)>>3]>>((j+2)&0x07))&0x01)^((tempkey[i][(j+44)>>3]>>((j+44)&0x07))&0x01);
				rh2[j]=((tempkey[i+1][j>>3]>>(j&0x07))&0x01)&((tempkey[i+1][(j+1)>>3]>>((j+1)&0x07))&0x01)^((tempkey[i+1][(j+2)>>3]>>((j+2)&0x07))&0x01)^((tempkey[i+1][(j+44)>>3]>>((j+44)&0x07))&0x01);
			}
			rh[j]=rh2[j]^rh[j];
			k=0;
			while(buffer[j][k]!='\0')
			{
				fprintf(fp2,"%c",buffer[j][k]);
				k++;
			}
			fprintf(fp2,"=");
			fprintf(fp2,"%d\n",rh[j]);
		}
		fclose(fp2);
		//调用SAT求解器,求解fin方程的所有可能的解,返回解得数量
		//printf("Solve Begin\n");
		solve(searnum,searpath,equnum);
		//printf("Solve Done\n");
		solnum=getsolnum(sol);
		//将文件中的解返回,然后随机选取一个解
		//解得数量控制在100组内,读取后需要去重
		//解得形式:80个0,1,对应的是key0到key80,在拼装的时候注意顺序
		//system("del E:\\Ans.txt");
		//system("del Ans.txt");
		system("del Ans");
		pick=rand()%solnum;
		for(j=0;j<10;j++)
		{
			temp=0;
			for(k=0;k<8;k++)
				temp=temp|(sol[pick][j*8+k]<<k);
			twokeysum[i/2][j]=temp;//只有一半
		}
	}

}


/////为三次方程选择随机密钥
void genrandomkeyV3(u32 randomkey[][10],u32 twokeysum[][10])
{
	FILE *fp,*fp2;
	u32 tempkey[80][10];
	u32 i,keynum=80,j,k,searnum=10,rh[80]={0};
	//u32 rh[80];
	u32 solnum,temp,temp1,temp2,temp3,temp4,temp5,temp6,temp7,temp8;
	u32 pick,equnum=38;
	u8 sol[100][80];
	char searpath[1000]="finequ\0";
	char c,buffer[80][200];
	fp=fopen("equV2","r");
	for(i=0;i<80;i++)
		for(j=0;j<200;j++)
			buffer[i][j]=0;
	c=fgetc(fp);
	for(i=0;i<equnum;i++)
	{
		j=0;
		while(c!='\n')
		{
			buffer[i][j++]=c;
			c=fgetc(fp);
		}
		c=fgetc(fp);
	}
	fclose(fp);
	for(i=0;i<keynum;i++)
		choose_random_key(tempkey[i]);
	//直接随机选的
	for(i=0;i<keynum;i++)
		for(j=0;j<10;j++)
			randomkey[i][j]=tempkey[i][j];



	/////两个密钥之和
	for(i=0;i<100;i++)
		for(j=0;j<80;j++)
			sol[i][j]=0;

	for(i=0;i<keynum;i=i+2)
	{
		fp2=fopen("finequ","w");
		for(j=0;j<equnum;j++)
		{
			//rh[j]=(((tempkey[i][(3*j)>>3]>>((3*j)&0x07))&0x01)&((tempkey[i][(3*j+1)>>3]>>((3*j+1)&0x07))&0x01))^((tempkey[i][(3*j+2)>>3]>>((3*j+2)&0x07))&0x01);
			//temp=(((tempkey[i+1][(3*j)>>3]>>((3*j)&0x07))&0x01)&((tempkey[i+1][(3*j+1)>>3]>>((3*j+1)&0x07))&0x01))^((tempkey[i+1][(3*j+2)>>3]>>((3*j+2)&0x07))&0x01);
			//temp=(((tempkey[i+1][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+1][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+1][(j+27)>>3]>>((j+27)&0x07))&0x01)((tempkey[i+1][(j)>>3]>>((j)&0x07))&0x01);
			//temp1=(((tempkey[i+1][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+1][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+1][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i+1][(j)>>3]>>((j)&0x07))&0x01);
			//temp2=(((tempkey[i+1][(j+42)>>3]>>((j+42)&0x07))&0x01)&((tempkey[i+1][(j+43)>>3]>>((j+43)&0x07))&0x01))^((tempkey[i+1][(j+44)>>3]>>((j+44)&0x07))&0x01)^((tempkey[i+1][(j+17)>>3]>>((j+17)&0x07))&0x01);
			//temp3=(((tempkey[i+1][(j+41)>>3]>>((j+41)&0x07))&0x01)&((tempkey[i+1][(j+42)>>3]>>((j+42)&0x07))&0x01))^((tempkey[i+1][(j+43)>>3]>>((j+43)&0x07))&0x01)^((tempkey[i+1][(j+16)>>3]>>((j+16)&0x07))&0x01);
			//temp4=(((tempkey[i+1][(j+40)>>3]>>((j+40)&0x07))&0x01)&((tempkey[i+1][(j+41)>>3]>>((j+41)&0x07))&0x01))^((tempkey[i+1][(j+42)>>3]>>((j+42)&0x07))&0x01)^((tempkey[i+1][(j+15)>>3]>>((j+15)&0x07))&0x01);
			temp1=(((tempkey[i+1][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+1][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+1][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i+1][(j)>>3]>>((j)&0x07))&0x01);
			temp2=(((tempkey[i+1][(j+40)>>3]>>((j+40)&0x07))&0x01)&((tempkey[i+1][(j+41)>>3]>>((j+41)&0x07))&0x01))^((tempkey[i+1][(j+42)>>3]>>((j+42)&0x07))&0x01)^((tempkey[i+1][(j+15)>>3]>>((j+15)&0x07))&0x01);
			temp3=(((tempkey[i+1][(j+39)>>3]>>((j+39)&0x07))&0x01)&((tempkey[i+1][(j+40)>>3]>>((j+40)&0x07))&0x01))^((tempkey[i+1][(j+41)>>3]>>((j+41)&0x07))&0x01)^((tempkey[i+1][(j+14)>>3]>>((j+14)&0x07))&0x01);
			temp4=(((tempkey[i+1][(j+38)>>3]>>((j+38)&0x07))&0x01)&((tempkey[i+1][(j+39)>>3]>>((j+39)&0x07))&0x01))^((tempkey[i+1][(j+40)>>3]>>((j+40)&0x07))&0x01)^((tempkey[i+1][(j+13)>>3]>>((j+13)&0x07))&0x01);

			temp=temp1^temp2^(temp3&temp4);
			
			temp5=(((tempkey[i][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i][(j)>>3]>>((j)&0x07))&0x01);
			temp6=(((tempkey[i][(j+40)>>3]>>((j+40)&0x07))&0x01)&((tempkey[i][(j+41)>>3]>>((j+41)&0x07))&0x01))^((tempkey[i][(j+42)>>3]>>((j+42)&0x07))&0x01)^((tempkey[i][(j+15)>>3]>>((j+15)&0x07))&0x01);
			temp7=(((tempkey[i][(j+39)>>3]>>((j+39)&0x07))&0x01)&((tempkey[i][(j+40)>>3]>>((j+40)&0x07))&0x01))^((tempkey[i][(j+41)>>3]>>((j+41)&0x07))&0x01)^((tempkey[i][(j+14)>>3]>>((j+14)&0x07))&0x01);
			temp8=(((tempkey[i][(j+38)>>3]>>((j+38)&0x07))&0x01)&((tempkey[i][(j+39)>>3]>>((j+39)&0x07))&0x01))^((tempkey[i][(j+40)>>3]>>((j+40)&0x07))&0x01)^((tempkey[i][(j+13)>>3]>>((j+13)&0x07))&0x01);

			rh[j]=temp5^temp6^(temp7&temp8);
			//temp=(((tempkey[i+1][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+1][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+1][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i+1][(j)>>3]>>((j)&0x07))&0x01);
			//rh[j]=(((tempkey[i][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i][(j)>>3]>>((j)&0x07))&0x01);
			rh[j]=temp^rh[j];
			k=0;
			while(buffer[j][k]!='\0')
			{
				fprintf(fp2,"%c",buffer[j][k]);
				k++;
			}
			fprintf(fp2,"=");
			fprintf(fp2,"%d\n",rh[j]);
		}
		fclose(fp2);
		//调用SAT求解器,求解fin方程的所有可能的解,返回解得数量
		solve(searnum,searpath,equnum);
		solnum=getsolnum(sol);
		//将文件中的解返回,然后随机选取一个解
		//解得数量控制在100组内,读取后需要去重
		//解得形式:80个0,1,对应的是key0到key80,在拼装的时候注意顺序
		//system("del E:\\Ans.txt");
		//system("del Ans.txt");
		system("del Ans");
		pick=rand()%solnum;
		for(j=0;j<10;j++)
		{
			temp=0;
			for(k=0;k<8;k++)
				temp=temp|(sol[pick][j*8+k]<<k);
			twokeysum[i/2][j]=temp;//只有一半
		}



	}

}




/////为特殊形式二次检测,选择随机密钥
void genrandomkey_qua(u32 randomkey[][10],u32 twokeysum[][10])
{
	FILE *fp,*fp2;
	u32 tempkey[160][10];
	u32 i,keynum=120,j,k,searnum=80,rh[80]={0};
	//u32 rh[80];
	u32 solnum,temp;
	u32 pick,equnum=76;
	u8 sol[100][80];
	char searpath[1000]="finequ\0";
	char c,buffer[80][80];
	fp=fopen("equ","r");
	for(i=0;i<80;i++)
		for(j=0;j<80;j++)
			buffer[i][j]=0;
	c=fgetc(fp);
	for(i=0;i<equnum;i++)
	{
		j=0;
		while(c!='\n')
		{
			buffer[i][j++]=c;
			c=fgetc(fp);
		}
		c=fgetc(fp);
	}
	fclose(fp);
	for(i=0;i<keynum;i++)
		choose_random_key(tempkey[i]);
	//直接随机选的
	for(i=0;i<keynum;i++)
		for(j=0;j<10;j++)
			randomkey[i][j]=tempkey[i][j];



	/////两个密钥之和
	for(i=0;i<100;i++)
		for(j=0;j<80;j++)
			sol[i][j]=0;

	for(i=0;i<keynum;i=i+3)
	{
		//k1+k2;
		fp2=fopen("finequ","w");
		for(j=0;j<equnum;j++)
		{
			temp=(((tempkey[i+1][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+1][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+1][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i+1][(j)>>3]>>((j)&0x07))&0x01);
			rh[j]=(((tempkey[i][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i][(j)>>3]>>((j)&0x07))&0x01);
			rh[j]=temp^rh[j];
			k=0;
			while(buffer[j][k]!='\0')
			{
				fprintf(fp2,"%c",buffer[j][k]);
				k++;
			}
			fprintf(fp2,"=");
			fprintf(fp2,"%d\n",rh[j]);
		}
		fclose(fp2);
		solve(searnum,searpath,equnum);
		solnum=getsolnum(sol);
		system("del Ans");
		pick=rand()%solnum;
		for(j=0;j<10;j++)
		{
			temp=0;
			for(k=0;k<8;k++)
				temp=temp|(sol[pick][j*8+k]<<k);
			twokeysum[(i/3)*4+0][j]=temp;//只有一半
		}
		//k1+k3
		fp2=fopen("finequ","w");
		for(j=0;j<equnum;j++)
		{
			temp=(((tempkey[i+2][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+2][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+2][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i+2][(j)>>3]>>((j)&0x07))&0x01);
			rh[j]=(((tempkey[i][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i][(j)>>3]>>((j)&0x07))&0x01);
			rh[j]=temp^rh[j];
			k=0;
			while(buffer[j][k]!='\0')
			{
				fprintf(fp2,"%c",buffer[j][k]);
				k++;
			}
			fprintf(fp2,"=");
			fprintf(fp2,"%d\n",rh[j]);
		}
		fclose(fp2);
		solve(searnum,searpath,equnum);
		solnum=getsolnum(sol);
		system("del Ans");
		pick=rand()%solnum;
		for(j=0;j<10;j++)
		{
			temp=0;
			for(k=0;k<8;k++)
				temp=temp|(sol[pick][j*8+k]<<k);
			twokeysum[(i/3)*4+1][j]=temp;//只有一半
		}

		//k2+k3
		fp2=fopen("finequ","w");
		for(j=0;j<equnum;j++)
		{
			temp=(((tempkey[i+2][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+2][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+2][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i+2][(j)>>3]>>((j)&0x07))&0x01);
			rh[j]=(((tempkey[i+1][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+1][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+1][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i+1][(j)>>3]>>((j)&0x07))&0x01);
			rh[j]=temp^rh[j];
			k=0;
			while(buffer[j][k]!='\0')
			{
				fprintf(fp2,"%c",buffer[j][k]);
				k++;
			}
			fprintf(fp2,"=");
			fprintf(fp2,"%d\n",rh[j]);
		}
		fclose(fp2);
		solve(searnum,searpath,equnum);
		solnum=getsolnum(sol);
		system("del Ans");
		pick=rand()%solnum;
		for(j=0;j<10;j++)
		{
			temp=0;
			for(k=0;k<8;k++)
				temp=temp|(sol[pick][j*8+k]<<k);
			twokeysum[(i/3)*4+2][j]=temp;//只有一半
		}
		//k1+k2+k3
		fp2=fopen("finequ","w");
		for(j=0;j<equnum;j++)
		{
			temp=(((tempkey[i+2][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+2][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+2][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i+2][(j)>>3]>>((j)&0x07))&0x01);
			rh[j]=(((tempkey[i+1][(j+25)>>3]>>((j+25)&0x07))&0x01)&((tempkey[i+1][(j+26)>>3]>>((j+26)&0x07))&0x01))^((tempkey[i+1][(j+27)>>3]>>((j+27)&0x07))&0x01)^((tempkey[i+1][(j)>>3]>>((j)&0x07))&0x01);
			rh[j]=temp^rh[j];
			k=0;
			while(buffer[j][k]!='\0')
			{
				fprintf(fp2,"%c",buffer[j][k]);
				k++;
			}
			fprintf(fp2,"=");
			fprintf(fp2,"%d\n",rh[j]);
		}
		fclose(fp2);
		solve(searnum,searpath,equnum);
		solnum=getsolnum(sol);
		system("del Ans");
		pick=rand()%solnum;
		for(j=0;j<10;j++)
		{
			temp=0;
			for(k=0;k<8;k++)
				temp=temp|(sol[pick][j*8+k]<<k);
			twokeysum[(i/3)*4+3][j]=temp;//只有一半
		}

	}

}

