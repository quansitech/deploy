var path = require('path');
var express = require('express');
var exec = require('child_process').exec;

var app = express();

//可自己定义一个不太容易被猜到的路径
app.post('/自定义随机码', function(req, res) {
    //接收post信息，验证请求信息，请求时间

    //验证通过做镜像更新，docker容器登录（登录的密码建议放入环境变量），拉取最新镜像，启动镜像，复制镜像源码至宿主机
    var cmd = 'cd /mnt/docker-script && docker login --username 容器账号 --password 容器密码 registry.cn-shenzhen.aliyuncs.com && docker-compose pull 镜像名 && docker-compose up 镜像名 && docker cp 镜像名:/var/www/项目名 /mnt/www && rm -rf /mnt/www/项目名/app/Runtime/*';
    exec(cmd, function(err, stdout) {
        if (err) {
        console.error(err);
        res.status(500).end();
        } else {
        console.log('pull success! ');
        res.send('pull sucess!');
        console.log(stdout);
        res.status(200).end();
        }
    });
});

app.listen(1800, function() {
    console.log('webhook listening on %d', 1800);
});
  
