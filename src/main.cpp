#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickWindow>
#include <QDir>
#include <QFile>
#include <QProcessEnvironment>
#include <QDebug>
#include "hammergym.h"

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("hammer-gym"));
    // Keine Organization setzen: Dadurch löst AppDataLocation (QDirs) zu
    // <XDG_DATA_HOME>/hammer-gym auf, der von der Click-Apparmor-Whitelist
    // erlaubte Datapath (~/.local/share/hammer-gym/**).
    QCoreApplication::setOrganizationName(QString());

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                     &engine, [](const QList<QQmlError> &warnings) {
        for (const QQmlError &e : warnings) {
            qCritical().noquote() << "QML-Warnung:" << e.toString();
        }
    });

    // Desktop-Override per Umgebungsvariable; sonst QML-Pfad von bin/ aus finden.
    QString qmlPath;
    QString overridePath = QProcessEnvironment::systemEnvironment().value("HAMMERGYM_QML");
    if (!overridePath.isEmpty()) {
        qmlPath = overridePath;
    } else {
        QDir dir(QCoreApplication::applicationDirPath());
        qmlPath.clear();
        for (int i = 0; i < 5 && qmlPath.isEmpty(); ++i) {
            QString candidate = dir.absoluteFilePath("qml/Main.qml");
            if (QFile::exists(candidate)) {
                qmlPath = candidate;
            }
            dir.cdUp();
        }
        if (qmlPath.isEmpty()) {
            qmlPath = QDir(QCoreApplication::applicationDirPath())
                          .absoluteFilePath("../qml/Main.qml");
        }
    }

    if (!QFile::exists(qmlPath)) {
        qCritical() << "QML nicht gefunden:" << qmlPath
                    << "(Setze HAMMERGYM_QML, um den Pfad vorzugeben.)";
        return -1;
    }

    HammerGym gym;
    engine.rootContext()->setContextProperty("gym", &gym);

    engine.load(QUrl::fromLocalFile(qmlPath));
    if (engine.rootObjects().isEmpty()) {
        qCritical() << "QML konnte nicht geladen werden:" << qmlPath;
        return -1;
    }

    return app.exec();
}