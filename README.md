# boost ビルドプロジェクト

## 概要

boost C++ ライブラリは基本的にヘッダファイルで構成されていますが、一部ビルドが必要なものがあります。
この boost.build は iOS と Android 向けのビルドを行うためのスクリプトファイルです。

なお、 CODIANZ では下記のライブラリを使用しているため限定的にライブラリをビルドしますが、 `build.sh` の `BOOST_BUILD_LIBRARIES` スクリプトファイルを変更すれば他のライブラリもビルドが行えます。（一部のライブラリを他のライブラリとの依存関係があるため、すんなり行かない場合があります）
* atomic
* chrono
* date_time
* regex
* timer
* thread
* filesystem
* system


一部は、std に標準採用されているものもあるが、複数のビルド環境で同一のライブラリを使用することで機種依存を吸収する方針。しかし、一部、標準かboostかの境界線が曖昧なものも正直あるが、そこは個人的な歴史的背景があるので勘弁。


## 使用方法

```sh
$ ./build.sh (ios|Android)
```

## iOS ビルド準備

* ビルドで使用する Xcode を指定します。
```sh
$ sudo xcode-select --switch  /Applications/Xcode.10.3.app
```

## Android ビルド準備

* Android は `Android Studio` で `NDK (side by side)` と `CMake` を別途インストールします。
* NDK のパスがたまに仕様変更が入るので `build.sh` の `ANDROID_NDK` を適宜変更してください。


## ビルド方法

```sh
$ ./build.sh version target [build]
```

|パラメータ|必須|摘要|例|
|-|:-:|-|-|
|version|○|boost バージョン|1.69.0|
|target|○|ビルドターゲット（ios \| Android \| all）|ios|
|build| |ビルドする場合指定。ビルド済みライブラリを展開する場合は未指定。|build|


