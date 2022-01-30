// Author: FangFangTu
//Time: 2021/11/7 11:47
#include<stdio.h>
#include<stdlib.h>
#include<string.h>

extern void myprint(char* str, int isDir);

const int DIR_ENTRY_SIZE = 32;

typedef unsigned char byte;

byte getbyte(FILE* fat){
    return (unsigned char) fgetc(fat);
}
short getshort(FILE* fat){
    return fgetc(fat) | (fgetc(fat) << 8);
}
int getint(FILE* fat){
    return fgetc(fat) | (fgetc(fat) << 8) | (fgetc(fat) << 16) | (fgetc(fat) << 24);
}
int my_getline(char* s){
    int i=0;
    char c;
    while((c=getchar())!=EOF && c!='\n')
        s[i++] = c;
    s[i++] = '\0';
    return i;
}

// 引导扇区参数块
typedef struct BIOS_Parameter_Block {
    short bytes_per_sector;
    byte sectors_per_cluster;
    short reserved_sectors;
    byte FATs;
    short directory_entries;
    short sectors_per_FAT;
}BPB;
BPB* bpb;
int sectors_of_rootDir;
int bytes_per_cluster;
int start_of_FAT;
int start_of_rootDir;
int start_of_data;
int clus_to_addr(short cluster){        // 根据簇号计算起始地址
    return start_of_data + (int)(cluster - 2) * bytes_per_cluster;
}
int next_clus(int clus_num, FILE* fat){            // 根据当前簇号寻找下一簇号
    int addr= start_of_FAT + clus_num/2 * 3*sizeof(byte);
    fseek(fat, addr, SEEK_SET);
    int two_clus = getbyte(fat) | (getbyte(fat) << 8) | (getbyte(fat) << 16);
    int next;
    if(clus_num%2==0)
         next = 0x00000fff & two_clus;
    else next = (0x00fff000 & two_clus) >> 12;
    return next;
}

// 目录项
typedef struct Directory_Entry {
    char dir_name[9];
    byte dir_attr;
    short dir_fstClus;
    int dir_fileSize;

    char ch_dir[2];
    char ch_arc[2];
}DE;
void read_dir_entry(DE* de, FILE* fat){         // 读取一个目录项
    for(int i=0;i<sizeof(de->dir_name)-1;i++){
        char c = getbyte(fat);
        if(c==' ') continue;
        de->dir_name[i] = c;
    }
    de->dir_name[8] = '\0';
    fseek(fat, 0x0B-0x08, SEEK_CUR);
    de->dir_attr = getbyte(fat);
    fseek(fat, 0x1A-0x0C, SEEK_CUR);
    de->dir_fstClus = getshort(fat);
    de->dir_fileSize = getint(fat);
}


// 目录树
typedef struct tree{
    DE entry;
    struct tree* left;
    struct tree* right;
}dir_tree;
dir_tree* root;
char prefix[32];    // 输出目录的前缀
int len = 0;        // 前缀的长度
void add_prefix(char* name){    // 将name添加到前缀中
    strcpy(&prefix[len], name);
    len = strlen(prefix);
    prefix[len++] = '/';
}
void del_prefix(int dellen){    // 删除dellen长度的前缀
    prefix[--len] = '\0';
    while(dellen-->0){
        prefix[--len] = '\0';
    }
}
void reset_prefix(){            // 重置前缀为空
    memset(prefix, 0, len);
    len = 0;
}

void print_children(dir_tree* r){   // 打印该节点子目录和子文件数量
    int ch_dir=0, ch_arc=0;
    dir_tree* cur = r->left;
    while(cur!=NULL){
        if(cur->entry.dir_attr==0x10 && cur->entry.dir_name[0]!='.') ch_dir++;
        else if(cur->entry.dir_attr==0x20) ch_arc++;
        cur = cur->right;
    }
    char children[4];
    sprintf(children, "%d", ch_dir);
    myprint(children, 0);
    myprint(" ", 0);
    sprintf(children, "%d", ch_arc);
    myprint(children, 0);
}
void print_entry(dir_tree* rt, byte isList){    // 打印节点信息
    if(rt->entry.dir_attr==0x10 && rt->entry.dir_name[0]!='.'){
        myprint(prefix, 0);
        myprint(rt->entry.dir_name, 0);
        myprint("/ ", 0);
        if(isList) print_children(rt);
        myprint(":\n", 0);
        
        dir_tree* cur = rt->left;
        while(cur!=NULL){
            if(cur->entry.dir_attr==0x10){
                myprint(cur->entry.dir_name, 1);
                myprint("  ", 0);
                if(isList){
                    if(cur->entry.dir_name[0]!='.')
                        print_children(cur);    
                    myprint("\n", 0);
                }
            }
            if(cur->entry.dir_attr==0x20){
                myprint(cur->entry.dir_name, 0);
                myprint("  ", 0);
                if(isList){
                    char size[9];
                    sprintf(size, "%d", cur->entry.dir_fileSize);
                    myprint(size, 0);
                    myprint("\n", 0);
                }
            }
            cur = cur->right;
        }
        if(!isList) myprint("\n", 0);
        myprint("\n", 0);
    }
}
void print_tree(dir_tree* rt, byte isList){     // 打印以rt为根的树
    print_entry(rt, isList);

    if(rt->left!=NULL){
        add_prefix(rt->entry.dir_name);
        print_tree(rt->left, isList);
        del_prefix(strlen(rt->entry.dir_name));
    }
    if(rt->right!=NULL)
        print_tree(rt->right, isList);
}


void load_boot_record(FILE* fat);
void build_dir_tree(FILE* fat);
char* check_ls(byte* flag);
void exec_ls(char* dir, byte isList);
char* check_cat();
void exec_cat(char* dir, FILE* fat);

int main(){
    // tips：
    // 1. 指针变量记得初始化，否则默认为NULL
    // 2. 全局变量不能在编译时确定，即不能把初始化放外面
    bpb = (BPB*)malloc(sizeof(BPB));
    
    // 读取FAT12镜像文件
    FILE* fat = fopen("./a.img", "rb");
    
    // 把引导扇区读进来
    load_boot_record(fat);

    // 根据引导扇区找到fat、dir、data的起始位置
    sectors_of_rootDir = 1 * bpb->directory_entries * DIR_ENTRY_SIZE / bpb->bytes_per_sector;
    bytes_per_cluster = 1 * bpb->bytes_per_sector * bpb->sectors_per_cluster;
    start_of_FAT = 1 * bpb->reserved_sectors * bpb->bytes_per_sector;
    start_of_rootDir = start_of_FAT + 1 * bpb->sectors_per_FAT * bpb->FATs * bpb->bytes_per_sector;
    start_of_data = start_of_rootDir + 1 * sectors_of_rootDir * bpb->bytes_per_sector;
    
    // 构建目录树
    build_dir_tree(fat);
    // print_tree(root);
    
    // 解析命令
    char command[64];
    while(1){
        my_getline(command);
        char* op = strtok(command, " ");
        if(op==NULL) continue;
        if(strcmp(op, "exit")==0){
            myprint("Bye~\n", 1);
            break;
        }else if (strcmp(op, "ls")==0){
            byte isList = 0;
            char* dir = check_ls(&isList);
            if (dir==NULL){
                myprint("Wrong format\n", 1);
            }else{
                reset_prefix();
                exec_ls(dir, isList);
            }
        }else if (strcmp(op, "cat")==0){
            char* dir = check_cat();
            if (dir==NULL){
                myprint("Wrong format\n", 1);
            }else{
                exec_cat(dir, fat);
            }
        }else{ 
            myprint("Undefined command: ", 0);
            myprint(op, 1);
            myprint("\n", 0);
        }
    }
    
    // 关闭文件，退出
    fclose(fat);
    return 0;
}

void load_boot_record(FILE* fat){       // 加载引导扇区
    fseek(fat, 0x0B, SEEK_SET);
    bpb->bytes_per_sector = getshort(fat);
    bpb->sectors_per_cluster = getbyte(fat);
    bpb->reserved_sectors = getshort(fat);
    bpb->FATs = getbyte(fat);
    bpb->directory_entries = getshort(fat);
    fseek(fat, 0x16, SEEK_SET);
    bpb->sectors_per_FAT = getshort(fat);
}

byte peek(FILE* fat){                   // 查看文件指针当前的内容
    byte c = getbyte(fat);
    fseek(fat, -1 ,SEEK_CUR);
    return c;
}
void build_tree(FILE* fat, dir_tree* cur){  // 除了根目录，递归建树
    read_dir_entry(&(cur->entry), fat);
    
    byte c = peek(fat);
    if(c!=0 && c!=0xE5){ 
        cur->right = (dir_tree*)malloc(sizeof(dir_tree));
        build_tree(fat, cur->right);
    }

    if(cur->entry.dir_attr==0x10 && cur->entry.dir_name[0]!='.'){
        fseek(fat, clus_to_addr(cur->entry.dir_fstClus), SEEK_SET);
        cur->left = (dir_tree*)malloc(sizeof(dir_tree));
        build_tree(fat, cur->left);
    }   

}
void build_dir_tree(FILE* fat){             // 构建根目录树
    root = (dir_tree*)malloc(sizeof(dir_tree));
    root->entry.dir_attr = 0x10;

    fseek(fat, start_of_rootDir, SEEK_SET);
    root->left = (dir_tree*)malloc(sizeof(dir_tree));
    build_tree(fat, root->left);
}

dir_tree* dir_to_tree(char* dir){           // 根据文件名找到目录树节点
    dir_tree* r = root;
    char* dir_name = strtok(dir, "/");
    while(dir_name){
        add_prefix(r->entry.dir_name);
        r = r->left;
        while(strcmp(r->entry.dir_name, dir_name)!=0){
            r = r->right;
            if(r==NULL){
                myprint("No such path\n", 1);
                return NULL;
            }
        }
        dir_name = strtok(NULL, "/");
    }
    return r;
}

char* check_ls(byte* flag){             // 检查ls格式
    char* dir = NULL;
    char* arg = strtok(NULL, " ");
    while(arg){
        switch (arg[0])
        {
        case '-':
            for(int i=1;arg[i]!='\0';i++){
                if(arg[i]!='l') return NULL;
            }
            *flag = 1;
            break;
        case '/':
            if(dir==NULL){
                dir = (char*)malloc(32*sizeof(char));
                strcpy(dir, arg);
            }else return NULL;
            break;
        default:
            return NULL;
        }
        arg = strtok(NULL, " ");
    }
    if(dir==NULL)
        dir = "/";
    return dir;   
}
void exec_ls(char* dir, byte isList){   // 执行ls命令
    dir_tree* r = dir_to_tree(dir);
    if(r==NULL) return ;
    if(r->entry.dir_attr!=0x10){
        myprint("Not a directory\n", 1);
    }else{
        print_entry(r, isList);
        add_prefix(r->entry.dir_name);
        print_tree(r->left, isList);
    }
}

char* check_cat(){                      // 检查cat格式
    char* dir = NULL;
    char* arg = strtok(NULL, " ");
    while(arg){
        switch (arg[0])
        {
        case '/':
            if(dir==NULL){
                dir = (char*)malloc(32*sizeof(char));
                strcpy(dir, arg);
            }else return NULL;
            break;
        default:
            return NULL;
        }
        arg = strtok(NULL, " ");
    }
    return dir;  
}
void exec_cat(char* dir, FILE* fat){    // 执行cat命令
    dir_tree* r = dir_to_tree(dir);
    if(r==NULL) return ;
    if(r->entry.dir_attr!=0x20){
        myprint("Not archive document\n", 1);
    }else{
        int clus_num = r->entry.dir_fstClus;
        while(clus_num<0x0ff7){
            fseek(fat, clus_to_addr(clus_num), SEEK_SET);
            // error: malloc(): corrupted top size
            // 原因：上一次数组越界，可能是strcpy，memset等
            char* cluster = (char*)malloc((bytes_per_cluster+1)*sizeof(char));
            for(int i=0;i<bytes_per_cluster;i++){
                cluster[i] = getbyte(fat);
            }
            myprint(cluster, 0);
            clus_num = next_clus(clus_num, fat);
            if(clus_num==0x0ff7)
                myprint("Oops, a bad cluster\n", 1);
        }
    }
}