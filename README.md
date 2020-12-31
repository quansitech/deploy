# 基于阿里云容器服务的源码持续集成发布方案(php)

### 相关背景
过去我们一直采用阿里云git webhook的方式更新源码，当项目完成上线会将用户的服务器的ssh key加入到读取专用git账号。这时就存在一个风险，客户的服务器只要知道项目地址，就可以随意拉取其他项目代码，存在极大的安全隐患。当然，也可以给用户注册一个专用的git账号，再将该账号赋予相应的项目代码权限。但由于每次注册阿里云账号都必须填写一堆资料，比较麻烦（或者干脆自己搭建gitlab服务）。后来接触到阿里的容器服务，发现可以对子账号设置相应的容器拉取权限，就有了该发布方案。

### 基本原理
+ 将源码作为一个独立的镜像构建，构建的过程中完成代码更新，依赖包的安装，启动时执行数据库的迁移。具体做法可查看Dockerfile。
+ 分别构建其他服务容器，如php-fpm，nginx，mysql等
+ 构建一个webhook服务，当源码容器构建完成后，自动触发镜像更新，镜像启动，镜像源码copy
+ php-fpm，nginx等容器以copy到宿主机的源码作为路径运行服务，需要持久化的文件另外挂载进相关容器

可参考docker-compose.yml和app.js(基于node的webhook服务)理解相关部署思路。

### 操作步骤
以下设计仓库源码的使用，都需要按自己的需要，根据源码的注释提示做相应修改，否则无法运行成功。

+ 安装docker(ubuntu)

    卸载旧docker
    ```
    $ sudo apt-get remove docker \
                docker-engine \
                docker.io
    ```

    apt安装,具体命令不作细介绍
    ```
    $ sudo apt-get update

    $ sudo apt-get install \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common

    $ curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -

    $ sudo add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
    ```

    安装docker-ce
    ```
    $ sudo apt-get update

    $ sudo apt-get install docker-ce
    ```
  
+ 安装docker(centos)
    
    卸载旧docker
    ```
    $ sudo yum remove docker \
                      docker-client \
                      docker-client-latest \
                      docker-common \
                      docker-latest \
                      docker-latest-logrotate \
                      docker-logrotate \
                      docker-selinux \
                      docker-engine-selinux \
                      docker-engine
    ```
  
    yum安装
    ```
    $ sudo yum install -y yum-utils \
               device-mapper-persistent-data \
               lvm2
    ```
  
    执行下面的命令添加 yum 软件源
    ```
    $ sudo yum-config-manager \
        --add-repo \
        https://mirrors.ustc.edu.cn/docker-ce/linux/centos/docker-ce.repo
    
    $ sudo sed -i 's/download.docker.com/mirrors.ustc.edu.cn\/docker-ce/g' /etc/yum.repos.d/docker-ce.repo
    ```
  
    安装 Docker CE
    ```
    $ sudo yum makecache fast
    $ sudo yum install docker-ce
    ```
  
    启动 docker CE
    ```
    $ sudo systemctl enable docker
    $ sudo systemctl start docker
    ```
  
+ 添加docker用户组

    建立 docker 用户组，将uid为1000的用户加入docker用户组，可查看etc/passwd uid 1000对应的账户,如果没有自行新增
    ```
    $ sudo groupadd docker

    $ sudo usermod -aG docker $username
    ```

+ 安装docker-compose
    ```
    $ sudo sh -c "curl -L https://github.com/docker/compose/releases/download/1.23.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
    $ sudo chmod +x /usr/local/bin/docker-compose
    ```

+ 安装node和npm

    ubuntu
    ```
    $ curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -

    $ sudo apt-get install nodejs
    ```
  
    centos
    ```
    $ sudo yum install epel-release
    $ curl --silent --location https://rpm.nodesource.com/setup_10.x | bash -
    $ sudo yum install -y nodejs
    ```

    配置npm仓库
    ```
    $ sudo npm install -g nrm

    $ nrm ls
    * npm ---- https://registry.npmjs.org/
      cnpm --- http://r.cnpmjs.org/
      taobao - https://registry.npm.taobao.org/
      nj ----- https://registry.nodejitsu.com/
      rednpm - http://registry.mirror.cqupt.edu.cn/
      npmMirror  https://skimdb.npmjs.com/registry/
      edunpm - http://registry.enpmjs.org/

    #使用淘宝镜像
    $ nrm use taobao
    ```

    安装express包，使用源码里的package.json，执行npm install进行包安装。源码里的app.js是webhook启动文件。

+ 安装supervisor

  ubuntu
  ```
  $ sudo apt-get install supervisor
  ```
  
  centos
  ```
  $ sudo yum install supervisor
  ```

  配置supervisor webhook守护进程
  ```
  $ cd /etc/supervisor/conf.d

  #将源码里的webhook.conf复制到该位置

  $ sudo supervisorctl 
  #进入命令行后执行update 加载webhook.conf配置文件，加载后webhook即会自动启动
  ```

+ 构建源码镜像

    将Dockerfile复制到项目跟目录下，然后去阿里云的容器服务创建一个基于项目git仓库的镜像，具体操作可查阅阿里云容器服务手册。

+ 设置用户子账号，并设置操作权限

    子账号的创建及其设置策略，同样查阅相关手册 (注意：开通完子账号后还需要用子账号登录一次容器服务页面，设置登录密码)

+ 拉取并配置服务镜像
   
   将docker-compose.yml复制到服务器，并拉取相关的镜像，第一次拉取需要登录docker仓库。拉取源码镜像后使用docker cp命令将容器里的源码拉出。宿主机的源码路径最好和nginx php-fpm的路径一致，都放在/var/www下。以上操作最好全部在uid为1000的用户下执行。

+ 设置触发器

   设置源码镜像构建完成的触发器，触发器地址为webhook设置的路由地址，采用全部触发的方式（如有特殊需求自行设计）。
   
+ 定期清理垃圾镜像
   
   由于经常要重新拉镜像，这样就会导致大量的垃圾镜像产生
   
   ```
   //在crontab设置
   0 0 * * * docker system prune -f
   ```

+ 大功告成
   
   配置完以上步骤，并且都能正常工作，一个docker的持续集成的发布流程就建立了。搭配阿里云的云效可设计系列的自动化测试，持续部署的开发发布流程。可查看楼主的另外一篇文章[基于云效和swoole构建的轻量级持续集成方案](https://github.com/tiderjian/qsci)
  
